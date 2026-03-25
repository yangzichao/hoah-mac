import Foundation

@MainActor
extension AIEnhancementService {
    fileprivate func waitForRateLimit(for session: ActiveSession?) async throws -> TimeInterval {
        let interval = currentRateLimitInterval(for: session)
        var waited: TimeInterval = 0
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < interval {
                waited = interval - timeSinceLastRequest
                try await Task.sleep(nanoseconds: UInt64(waited * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
        return waited
    }

    fileprivate func getSystemMessage(
        for mode: EnhancementPrompt,
        transcriptText: String,
        promptOverride: CustomPrompt? = nil
    ) async -> String {
        let userProfileSection = if !userProfileContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            "\n\n<USER_PROFILE>\n\(userProfileContext.trimmingCharacters(in: .whitespacesAndNewlines))\n</USER_PROFILE>"
        } else {
            ""
        }

        let allContextSections = userProfileSection
        let resolvedPrompt = promptOverride ?? activePrompt

        if let resolvedPrompt {
            var promptText = resolvedPrompt.finalPromptText
            
            // Handle Polish mode with enhancement toggles
            if resolvedPrompt.id == PredefinedPrompts.polishPromptId {
                let formalWriting = appSettings?.isPolishFormalWritingEnabled ?? false
                let professional = appSettings?.isPolishProfessionalEnabled ?? false
                
                // If any toggle is enabled, use the generated prompt instead of the base Polish prompt
                if formalWriting || professional {
                    let generatedPromptText = PredefinedPrompts.generatePolishPromptText(
                        formalWriting: formalWriting,
                        professional: professional
                    )
                    // System instructions wrapper is deprecated; prompts are now self-contained.
                    promptText = generatedPromptText
                }
            }
            
            // Handle Translate mode with target language replacement
            if resolvedPrompt.id == PredefinedPrompts.translatePromptId {
                let storedTarget = (appSettings?.translationTargetLanguage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let resolved = TranslationLanguage.resolveUserProvidedTarget(storedTarget) {
                    promptText = promptText.replacingOccurrences(of: "{{TARGET_LANGUAGE}}", with: resolved.replacement)
                }

                if storedTarget.isEmpty || promptText.contains("{{TARGET_LANGUAGE}}") {
                    let fallback = inferFallbackTranslationTarget(from: transcriptText)
                    promptText = promptText.replacingOccurrences(of: "{{TARGET_LANGUAGE}}", with: fallback)
                }
            }

            // Handle Second Translate mode with target language 2 replacement
            if resolvedPrompt.id == PredefinedPrompts.translatePrompt2Id {
                let storedTarget2 = (appSettings?.translationTargetLanguage2 ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let resolved = TranslationLanguage.resolveUserProvidedTarget(storedTarget2) {
                    promptText = promptText.replacingOccurrences(of: "{{TARGET_LANGUAGE_2}}", with: resolved.replacement)
                }

                if storedTarget2.isEmpty || promptText.contains("{{TARGET_LANGUAGE_2}}") {
                    let fallback = inferFallbackTranslationTarget(from: transcriptText)
                    promptText = promptText.replacingOccurrences(of: "{{TARGET_LANGUAGE_2}}", with: fallback)
                }
            }
            return promptText + allContextSections
        } else {
            guard let fallback = activePrompts.first(where: { $0.id == PredefinedPrompts.defaultPromptId }) ?? activePrompts.first else {
                return allContextSections
            }
            return fallback.finalPromptText + allContextSections
        }
    }

    private func inferFallbackTranslationTarget(from transcriptText: String) -> String {
        let interfaceCode = appSettings?.appInterfaceLanguage ?? "system"
        switch AppLanguage(code: interfaceCode) {
        case .simplifiedChinese:
            return "Chinese"
        case .english, .system:
            return "English"
        }
    }

    func makeRequest(
        text: String,
        mode: EnhancementPrompt,
        promptOverride: CustomPrompt? = nil
    ) async throws -> String {
        var session = activeSession

        // If we somehow lost the runtime session (e.g. after a config switch), try to rehydrate once before failing.
        if session == nil {
            aiService.hydrateActiveConfiguration()
            rebuildActiveSession()
            session = activeSession
        }

        guard let initialSession = session else {
            throw EnhancementError.notConfigured
        }
        
        let shouldForceRefresh = lastRuntimeErrorMessage != nil &&
            lastRuntimeErrorConfigId == appSettings?.activeAIConfigurationId
        let refreshedSession = try await refreshSessionIfNeeded(
            initialSession,
            forceRefresh: shouldForceRefresh
        )
        activeSession = refreshedSession

        guard !text.isEmpty else {
            return "" // Silently return empty string instead of throwing error
        }

        let formattedText = "\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"
        let systemMessage = await getSystemMessage(
            for: mode,
            transcriptText: text,
            promptOverride: promptOverride
        )
        
        // Persist the exact payload being sent (also used for UI)
        await MainActor.run {
            self.lastSystemMessageSent = systemMessage
            self.lastUserMessageSent = formattedText
        }

        // Log the message being sent to AI enhancement
        logger.notice("AI Enhancement - System Message: \(systemMessage, privacy: .public)")
        logger.notice("AI Enhancement - User Message: \(formattedText, privacy: .public)")

        let rateLimitWait = try await waitForRateLimit(for: refreshedSession)
        if rateLimitWait > 0 {
            logger.notice("AI Enhancement - Rate limit wait: \(rateLimitWait, format: .fixed(precision: 3))s")
        }

        return try await makeRequestWithRetry(
            systemMessage: systemMessage,
            formattedText: formattedText,
            session: refreshedSession
        )
    }

    fileprivate func makeRequestWithRetry(systemMessage: String, formattedText: String, session: ActiveSession, maxRetries: Int = 3, initialDelay: TimeInterval = 1.0) async throws -> String {
        var retries = 0
        var currentDelay = initialDelay

        while retries < maxRetries {
            do {
                return try await performRequest(systemMessage: systemMessage, formattedText: formattedText, session: session)
            } catch let error as EnhancementError {
                switch error {
                case .networkError, .serverError, .rateLimitExceeded:
                    retries += 1
                    if retries < maxRetries {
                        logger.warning("Request failed, retrying in \(currentDelay)s... (Attempt \(retries)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        currentDelay *= 2 // Exponential backoff
                    } else {
                        logger.error("Request failed after \(maxRetries) retries.")
                        throw error
                    }
                default:
                    throw error
                }
            } catch {
                // For other errors, check if it's a network-related URLError
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && [NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost].contains(nsError.code) {
                    retries += 1
                    if retries < maxRetries {
                        logger.warning("Request failed with network error, retrying in \(currentDelay)s... (Attempt \(retries)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        currentDelay *= 2 // Exponential backoff
                    } else {
                        logger.error("Request failed after \(maxRetries) retries with network error.")
                        throw EnhancementError.networkError
                    }
                } else {
                    throw error
                }
            }
        }

        // This part should ideally not be reached, but as a fallback:
        throw EnhancementError.enhancementFailed
    }

    fileprivate func performRequest(systemMessage: String, formattedText: String, session: ActiveSession) async throws -> String {
        switch session.provider {
        case .awsBedrock:
            return try await BedrockProvider.performRequest(
                systemMessage: systemMessage,
                userMessage: formattedText,
                session: session,
                fallbackRegion: aiService.bedrockRegion,
                baseTimeout: baseTimeout
            )
        case .anthropic:
            return try await AnthropicProvider.performRequest(
                systemMessage: systemMessage,
                formattedText: formattedText,
                session: session,
                baseTimeout: baseTimeout
            )
        case .doubao:
            return try await OpenAICompatibleProvider.performRequest(
                systemMessage: systemMessage,
                formattedText: formattedText,
                session: session,
                baseTimeout: baseTimeout
            )
        default:
            return try await OpenAICompatibleProvider.performRequest(
                systemMessage: systemMessage,
                formattedText: formattedText,
                session: session,
                baseTimeout: baseTimeout
            )
        }
    }

    func enhance(_ text: String, promptOverride: CustomPrompt? = nil) async throws -> (String, TimeInterval, String?) {
        let startTime = Date()
        let enhancementPrompt: EnhancementPrompt = .transcriptionEnhancement
        let resolvedPrompt = promptOverride ?? activePrompt
        let promptName = resolvedPrompt?.title

        do {
            if let session = activeSession {
                markEnhancing(with: session)
            }
            let hardTimeoutSeconds = baseTimeout + 5
            let result = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { [weak self] in
                    guard let self else { throw EnhancementError.enhancementFailed }
                    return try await self.makeRequest(
                        text: text,
                        mode: enhancementPrompt,
                        promptOverride: promptOverride
                    )
                }
                group.addTask {
                    // Use the same timeout window as the underlying network request,
                    // otherwise providers with higher latency will always fail.
                    try await Task.sleep(nanoseconds: UInt64(hardTimeoutSeconds * 1_000_000_000))
                    throw EnhancementError.timeout
                }
                guard let first = try await group.next() else {
                    throw EnhancementError.enhancementFailed
                }
                group.cancelAll()
                return first
            }
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            if let session = activeSession {
                markReady(with: session)
            }
            clearRuntimeError()
            let afterQA = applyQAOutputPreference(original: text, answer: result, prompt: resolvedPrompt)
            let finalResult = applyTranslateOutputPreference(original: text, translation: afterQA, prompt: resolvedPrompt)
            return (finalResult, duration, promptName)
        } catch {
            markError(error.localizedDescription)
            recordRuntimeError(error.localizedDescription, configId: appSettings?.activeAIConfigurationId)
            throw error
        }
    }

}

private extension AIEnhancementService {
    func currentRateLimitInterval(for session: ActiveSession?) -> TimeInterval {
        guard let session else { return rateLimitInterval }
        switch session.provider {
        case .doubao:
            return 0.2
        default:
            return rateLimitInterval
        }
    }

    /// Refresh AWS profile-based credentials before dispatching a request.
    func refreshSessionIfNeeded(_ session: ActiveSession, forceRefresh: Bool = false) async throws -> ActiveSession {
        guard case .bedrockSigV4(let credentials, let regionOverride) = session.auth,
              let profileName = credentials.profileName else {
            return session
        }
        
        let freshCredentials = try await awsProfileService.resolveFreshCredentials(
            for: profileName,
            forceRefresh: forceRefresh
        )
        guard freshCredentials != credentials else {
            return session
        }
        
        let updatedSession = ActiveSession(
            provider: session.provider,
            model: session.model,
            region: session.region,
            auth: .bedrockSigV4(freshCredentials, region: regionOverride)
        )
        markReady(with: updatedSession)
        return updatedSession
    }
    
    /// Appends the original transcript beneath the translation when the user opts in.
    func applyTranslateOutputPreference(original: String, translation: String, prompt: CustomPrompt?) -> String {
        // Check for first translation mode
        if prompt?.id == PredefinedPrompts.translatePromptId,
           appSettings?.showOriginalTextInTranslation == true {
            let trimmedTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedOriginal.isEmpty else { return trimmedTranslation }
            return "\(trimmedTranslation)\n\n\(trimmedOriginal)"
        }

        // Check for second translation mode
        if prompt?.id == PredefinedPrompts.translatePrompt2Id,
           appSettings?.showOriginalTextInTranslation2 == true {
            let trimmedTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedOriginal.isEmpty else { return trimmedTranslation }
            return "\(trimmedTranslation)\n\n\(trimmedOriginal)"
        }

        return translation
    }
    
    /// Shows the original question above the Q&A answer when enabled.
    func applyQAOutputPreference(original: String, answer: String, prompt: CustomPrompt?) -> String {
        guard prompt?.id == PredefinedPrompts.qnaPromptId,
              appSettings?.showOriginalTextInQA == true else {
            return answer
        }
        
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty else { return answer }
        
        let questionHeading = NSLocalizedString(
            "qa_output_heading_question",
            comment: "Heading shown above the original question in Q&A output"
        )
        let answerHeading = NSLocalizedString(
            "qa_output_heading_answer",
            comment: "Heading shown above the AI answer in Q&A output"
        )
        
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return "\(questionHeading)\n\(trimmedOriginal)\n\n\(answerHeading)\n\(trimmedAnswer)"
    }
}
