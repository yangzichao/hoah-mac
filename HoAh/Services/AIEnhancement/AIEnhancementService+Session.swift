import Foundation

@MainActor
extension AIEnhancementService {
    /// Apply a validated configuration and rebuild the runtime session snapshot
    func applyConfiguration(_ config: AIEnhancementConfiguration) {
        let token = beginSessionSwitch()
        markSwitching(configId: config.id)
        
        // Profile-based configs require async credential resolution
        if let profileName = config.awsProfileName, !profileName.isEmpty {
            // Keep switching state during async resolution (don't set session to nil yet)
            // This prevents brief "not configured" states during profile resolution
            let model = config.model.isEmpty ? (AIProvider(rawValue: config.provider)?.defaultModel ?? config.model) : config.model
            let region = config.region ?? aiService.bedrockRegion
            Task { [weak self] in
                guard let self else { return }
                do {
                    let credentials = try await awsProfileService.resolveFreshCredentials(for: profileName)
                    let resolvedRegion = credentials.region ?? region
                    await MainActor.run {
                        self.setActiveSession(
                            ActiveSession(
                                provider: .awsBedrock,
                                model: model,
                                region: resolvedRegion,
                                auth: .bedrockSigV4(credentials, region: resolvedRegion)
                            ),
                            token: token
                        )
                    }
                } catch {
                    await MainActor.run {
                        // Check token before applying error state to avoid overwriting a newer switch
                        guard self.isTokenValid(token) else {
                            // A newer switch has started, don't overwrite its state
                            self.logger.info("AWS Profile resolution failed but token expired, ignoring: \(profileName)")
                            return
                        }
                        // Provide meaningful error message for profile resolution failure
                        self.activeSession = nil
                        self.markError("Failed to resolve AWS Profile '\(profileName)': \(error.localizedDescription)")
                        self.logger.error("AWS Profile resolution failed for '\(profileName)': \(error.localizedDescription)")
                    }
                }
            }
            return
        }

        setActiveSession(buildSession(from: config), token: token)
    }

    /// Rebuild session from the currently active configuration or legacy settings
    func rebuildActiveSession() {
        if let config = aiService.activeConfiguration {
            applyConfiguration(config)
            return
        }
        
        let token = beginSessionSwitch()
        setActiveSession(buildLegacySession(), token: token)
    }

    func buildLegacySession() -> ActiveSession? {
        let provider = aiService.selectedProvider
        let model = aiService.currentModel

        switch provider {
        case .awsBedrock:
            let region = aiService.bedrockRegion
            let apiKey = aiService.apiKey
            guard !apiKey.isEmpty else { return nil }
            return ActiveSession(provider: .awsBedrock, model: model, region: region, auth: .bedrockBearer(apiKey, region: region))
        case .anthropic:
            let apiKey = aiService.apiKey
            guard !apiKey.isEmpty else { return nil }
            return ActiveSession(provider: provider, model: model, region: nil, auth: .anthropic(apiKey))
        case .azureOpenAI:
            // Azure OpenAI requires a resource-specific endpoint, which is only available in configuration profiles.
            return nil
        case .ollama:
            // Ollama is local, no API key needed
            return ActiveSession(provider: provider, model: model, region: nil, auth: .local)
        default:
            let apiKey = aiService.apiKey
            guard !apiKey.isEmpty else { return nil }
            return ActiveSession(provider: provider, model: model, region: nil, auth: .bearer(apiKey))
        }
    }

    func buildSession(from config: AIEnhancementConfiguration) -> ActiveSession? {
        guard let provider = AIProvider(rawValue: config.provider) else { return nil }
        let model = config.model.isEmpty ? provider.defaultModel : config.model

        switch provider {
        case .awsBedrock:
            // Profile handled asynchronously in applyConfiguration
            if let profileName = config.awsProfileName, !profileName.isEmpty {
                return nil
            }

            let region = config.region ?? aiService.bedrockRegion

            if let accessKeyId = config.awsAccessKeyId, !accessKeyId.isEmpty,
               let secretAccessKey = config.getAwsSecretAccessKey(), !secretAccessKey.isEmpty {
                let credentials = AWSCredentials(
                    accessKeyId: accessKeyId,
                    secretAccessKey: secretAccessKey,
                    sessionToken: nil,
                    region: region,
                    expiration: nil,
                    profileName: nil
                )
                return ActiveSession(
                    provider: .awsBedrock,
                    model: model,
                    region: region,
                    auth: .bedrockSigV4(credentials, region: region)
                )
            }

            if let apiKey = config.getApiKey(), !apiKey.isEmpty {
                return ActiveSession(provider: .awsBedrock, model: model, region: region, auth: .bedrockBearer(apiKey, region: region))
            }

            if !aiService.apiKey.isEmpty {
                return ActiveSession(provider: .awsBedrock, model: model, region: region, auth: .bedrockBearer(aiService.apiKey, region: region))
            }

            return nil

        case .anthropic:
            if let apiKey = config.getApiKey(), !apiKey.isEmpty {
                return ActiveSession(provider: provider, model: model, region: nil, auth: .anthropic(apiKey))
            }
            if !aiService.apiKey.isEmpty {
                return ActiveSession(provider: provider, model: model, region: nil, auth: .anthropic(aiService.apiKey))
            }
            return nil

        case .ollama:
            // Ollama is local, no API key needed
            return ActiveSession(provider: provider, model: model, region: nil, auth: .local, customEndpoint: config.customEndpoint)

        default:
            if let apiKey = config.getApiKey(), !apiKey.isEmpty {
                return ActiveSession(provider: provider, model: model, region: config.region, auth: .bearer(apiKey), customEndpoint: config.customEndpoint)
            }
            if !aiService.apiKey.isEmpty {
                return ActiveSession(provider: provider, model: model, region: config.region, auth: .bearer(aiService.apiKey), customEndpoint: config.customEndpoint)
            }
            return nil
        }
    }
}
