import Foundation

/// Handles OpenAI-compatible chat completions (OpenAI, Azure OpenAI, Groq, Gemini-compatible, OpenRouter, Cerebras, Ollama)
enum OpenAICompatibleProvider {
    static func performRequest(
        systemMessage: String,
        formattedText: String,
        session: AIEnhancementService.ActiveSession,
        baseTimeout: TimeInterval
    ) async throws -> String {
        // For local providers like Ollama, API key is optional
        let apiKey: String
        switch session.auth {
        case .bearer(let key):
            apiKey = key
        case .local:
            apiKey = ""
        default:
            throw EnhancementError.notConfigured
        }

        // For non-local providers, API key is required
        if !session.provider.isLocalProvider && apiKey.isEmpty {
            throw EnhancementError.notConfigured
        }

        // Use effectiveURL which considers custom endpoint for Ollama
        guard let url = URL(string: session.effectiveURL) else {
            throw EnhancementError.customError("Invalid API URL: \(session.effectiveURL)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if session.provider == .azureOpenAI && session.customEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            throw EnhancementError.customError("Azure OpenAI endpoint is not configured.")
        }
        if !apiKey.isEmpty {
            if session.provider.usesAPIKeyHeader {
                request.addValue(apiKey, forHTTPHeaderField: "api-key")
            } else {
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        request.timeoutInterval = baseTimeout

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemMessage],
            ["role": "user", "content": formattedText]
        ]

        var requestBody: [String: Any] = [
            "model": session.model,
            "messages": messages,
            "stream": false
        ]

        // Azure OpenAI uses deployment names, so model-family capability inference from the string is unreliable.
        if session.provider != .azureOpenAI {
            let noTemperatureModels = ["gpt-5-mini", "gpt-5-nano"]
            if !noTemperatureModels.contains(session.model) {
                requestBody["temperature"] = 0.3
            }

            if let reasoningEffort = ReasoningConfig.getReasoningParameter(for: session.model) {
                requestBody["reasoning_effort"] = reasoningEffort
            }
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancementError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = jsonResponse["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let enhancedText = message["content"] as? String else {
                    throw EnhancementError.enhancementFailed
                }

                let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                return filteredText
            } else if httpResponse.statusCode == 429 {
                throw EnhancementError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // For local providers, auth errors indicate a different issue
                if session.provider.isLocalProvider {
                    let errorString = String(data: data, encoding: .utf8) ?? "Authentication error"
                    throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
                }
                throw EnhancementError.apiKeyInvalid
            } else if httpResponse.statusCode == 404 && session.provider.isLocalProvider {
                // Model not found - prompt user to pull it
                throw EnhancementError.customError("Model '\(session.model)' not found. Run: ollama pull \(session.model)")
            } else if (500...599).contains(httpResponse.statusCode) {
                throw EnhancementError.serverError
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
            }

        } catch let error as EnhancementError {
            throw error
        } catch let error as URLError {
            // Better error messages for local providers
            if session.provider.isLocalProvider {
                switch error.code {
                case .cannotConnectToHost, .cannotFindHost:
                    throw EnhancementError.customError("Cannot connect to Ollama. Make sure it's running (ollama serve)")
                case .timedOut:
                    throw EnhancementError.customError("Connection to Ollama timed out. Is it running?")
                default:
                    throw EnhancementError.customError("Connection failed: \(error.localizedDescription)")
                }
            }
            throw error
        } catch {
            throw EnhancementError.customError(error.localizedDescription)
        }
    }
}
