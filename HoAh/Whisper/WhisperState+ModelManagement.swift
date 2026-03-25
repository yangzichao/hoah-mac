import Foundation
import SwiftUI

@MainActor
extension WhisperState {
    // Loads the default transcription model from UserDefaults
    func loadCurrentTranscriptionModel() {
        if let savedModelName = UserDefaults.hoah.string(forKey: "CurrentTranscriptionModel"),
           let savedModel = allAvailableModels.first(where: { $0.name == savedModelName }) {
            // Only restore local models if the file is actually present
            if savedModel.provider != .local ||
                availableModels.contains(where: { $0.name == savedModelName }) {
                currentTranscriptionModel = savedModel
                warmupActiveLocalModel(reason: "app launch restore")
                return
            }
        }
        
        // No saved model found – pick a default based on available downloads.
        selectDefaultTranscriptionModelIfNeeded()
        warmupActiveLocalModel(reason: "app launch default selection")
    }

    // Function to set any transcription model as default
    func setDefaultTranscriptionModel(_ model: any TranscriptionModel) {
        self.currentTranscriptionModel = model
        UserDefaults.hoah.set(model.name, forKey: "CurrentTranscriptionModel")
        
        // For cloud models, clear the old loadedLocalModel
        if model.provider != .local {
            self.loadedLocalModel = nil
        }
        
        // Enable transcription for cloud models immediately since they don't need loading
        if model.provider != .local {
            self.isModelLoaded = true
        }
        // Post notification about the model change
        NotificationCenter.default.post(name: .didChangeModel, object: nil, userInfo: ["modelName": model.name])
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        
        if model.provider == .local {
            warmupActiveLocalModel(reason: "model switch")
        }
    }
    
    func refreshAllAvailableModels() {
        let currentModelName = currentTranscriptionModel?.name
        let models = PredefinedModels.models

        allAvailableModels = models

        // Preserve current selection by name (IDs may change for dynamic models)
        if let currentName = currentModelName,
           let updatedModel = allAvailableModels.first(where: { $0.name == currentName }) {
            setDefaultTranscriptionModel(updatedModel)
        }
    }
    
    // MARK: - Default Model Selection
    
    /// Ensures there is a default transcription model selected when none
    /// has been persisted yet. Preference order:
    /// 1. A downloaded local Whisper model (prioritizing preferred defaults)
    private func selectDefaultTranscriptionModelIfNeeded() {
        guard currentTranscriptionModel == nil else { return }
        
        // Prefer a downloaded local model so we don't default to cloud/Apple Speech.
        if let downloadedLocal = availableModels.first,
           let template = allAvailableModels.first(where: { $0.name == downloadedLocal.name }) {
            setDefaultTranscriptionModel(template)
        }
    }
    
    /// Determines whether Native Apple transcription is available in this
    /// build and on the current OS. This mirrors the feature gating used
    /// in `NativeAppleTranscriptionService` so we don't select a model
    /// that can never successfully run.
    func isNativeAppleTranscriptionAvailable() -> Bool {
        #if canImport(Speech) && ENABLE_NATIVE_SPEECH_ANALYZER
        if #available(macOS 26, *) {
            return true
        } else {
            return false
        }
        #else
        return false
        #endif
    }
} 
