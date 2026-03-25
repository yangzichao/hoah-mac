import Foundation

extension WhisperState {
    var usableModels: [any TranscriptionModel] {
        allAvailableModels.filter { model in
            switch model.provider {
            case .local:
                return availableModels.contains { $0.name == model.name }
            case .nativeApple:
                if #available(macOS 26, *) {
                    return true
                } else {
                    return false
                }
            case .groq:
                return CloudAPIKeyManager.shared.hasKeys(for: "GROQ")
            case .elevenLabs:
                return CloudAPIKeyManager.shared.hasKeys(for: "ElevenLabs")
            case .openAI:
                return CloudAPIKeyManager.shared.hasKeys(for: "OpenAI")
            case .amazonTranscribe:
                return AmazonTranscribeConfigurationStore.shared.isConfigured()
            case .custom:
                guard let customModel = model as? CustomCloudModel else { return false }
                return customModel.hasApiKey
            }
        }
    }

    func preferredOfflineFallbackLocalModel(excluding excludedName: String? = nil) -> LocalModel? {
        // `allAvailableModels` gives us the canonical LocalModel definitions; `availableModels`
        // restricts the choice to models that are already downloaded on disk.
        let downloadedModelNames = Set(availableModels.map(\.name))
        let localModels = allAvailableModels.compactMap { $0 as? LocalModel }

        var prioritizedNames = PredefinedModels.largeV3ModelOrder
        prioritizedNames.append(contentsOf: localModels.map(\.name))

        var seen = Set<String>()
        for name in prioritizedNames where seen.insert(name).inserted {
            guard downloadedModelNames.contains(name), name != excludedName else { continue }
            if let model = localModels.first(where: { $0.name == name }) {
                return model
            }
        }

        return nil
    }

    func offlineFallbackLocalModel(for primaryModel: any TranscriptionModel, error: Error) -> LocalModel? {
        guard primaryModel.provider != .local else { return nil }
        guard error.isNetworkConnectivityFailure else { return nil }
        return preferredOfflineFallbackLocalModel(excluding: primaryModel.name)
    }

    func offlineFallbackLocalModel(for primaryModel: any TranscriptionModel, errorMessage: String) -> LocalModel? {
        guard primaryModel.provider != .local else { return nil }
        guard errorMessage.isNetworkConnectivityFailureMessage else { return nil }
        return preferredOfflineFallbackLocalModel(excluding: primaryModel.name)
    }
} 
