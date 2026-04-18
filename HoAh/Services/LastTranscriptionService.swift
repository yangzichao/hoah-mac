import Foundation
import SwiftData

class LastTranscriptionService: ObservableObject {
    private static let clipboardSourceRawValue = TranscriptionSource.clipboardAction.rawValue
    
    static func getLastTranscription(from modelContext: ModelContext) -> Transcription? {
        var descriptor = FetchDescriptor<Transcription>(
            predicate: #Predicate<Transcription> {
                $0.source == nil || $0.source != clipboardSourceRawValue
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        do {
            let transcriptions = try modelContext.fetch(descriptor)
            return transcriptions.first
        } catch {
            print("Error fetching last transcription: \(error)")
            return nil
        }
    }
    
    static func getRecentTranscriptions(limit: Int = 3, from modelContext: ModelContext) -> [Transcription] {
        var descriptor = FetchDescriptor<Transcription>(
            predicate: #Predicate<Transcription> {
                $0.source == nil || $0.source != clipboardSourceRawValue
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit * 3 // over-fetch, then filter
        
        do {
            let all = try modelContext.fetch(descriptor)
            let filtered = all.filter {
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return Array(filtered.prefix(limit))
        } catch {
            print("Error fetching recent transcriptions: \(error)")
            return []
        }
    }
    
    static func copyLastTranscription(from modelContext: ModelContext) {
        guard let lastTranscription = getLastTranscription(from: modelContext) else {
            Task { @MainActor in
                NotificationManager.shared.showNotification(
                    title: "No transcription available",
                    type: .error
                )
            }
            return
        }
        
        // Prefer successful enhanced text; fallback to original text
        let textToCopy: String = {
            if let enhancedText = lastTranscription.copyableEnhancedText {
                return enhancedText
            } else {
                return lastTranscription.text
            }
        }()
        
        let success = ClipboardManager.copyToClipboard(textToCopy)
        
        Task { @MainActor in
            if success {
                NotificationManager.shared.showNotification(
                    title: "Last transcription copied",
                    type: .success
                )
            } else {
                NotificationManager.shared.showNotification(
                    title: "Failed to copy transcription",
                    type: .error
                )
            }
        }
    }

    static func pasteLastTranscription(from modelContext: ModelContext) {
        guard let lastTranscription = getLastTranscription(from: modelContext) else {
            Task { @MainActor in
                NotificationManager.shared.showNotification(
                    title: "No transcription available",
                    type: .error
                )
            }
            return
        }
        
        let textToPaste = lastTranscription.text

        Task { @MainActor in
            PasteFlow.run(.init(text: textToPaste))
        }
    }

    static func pasteLastEnhancement(from modelContext: ModelContext) {
        guard let lastTranscription = getLastTranscription(from: modelContext) else {
            Task { @MainActor in
                NotificationManager.shared.showNotification(
                    title: "No transcription available",
                    type: .error
                )
            }
            return
        }
        
        // Prefer successful enhanced text; fallback to original text
        let textToPaste: String = {
            if let enhancedText = lastTranscription.copyableEnhancedText {
                return enhancedText
            } else {
                return lastTranscription.text
            }
        }()

        Task { @MainActor in
            PasteFlow.run(.init(text: textToPaste))
        }
    }
    
    static func retryLastTranscription(from modelContext: ModelContext, whisperState: WhisperState) {
        Task { @MainActor in
            guard let lastTranscription = getLastTranscription(from: modelContext),
                  let audioURLString = lastTranscription.audioFileURL,
                  let audioURL = URL(string: audioURLString),
                  FileManager.default.fileExists(atPath: audioURL.path) else {
                NotificationManager.shared.showNotification(
                    title: "Cannot retry: Audio file not found",
                    type: .error
                )
                return
            }
            
            guard let currentModel = whisperState.currentTranscriptionModel else {
                NotificationManager.shared.showNotification(
                    title: "No dictation model selected",
                    type: .error
                )
                return
            }
            
            let transcriptionService = AudioTranscriptionService(modelContext: modelContext, whisperState: whisperState)
            do {
                let newTranscription = try await transcriptionService.retranscribeAudio(from: audioURL, using: currentModel)
                
                let textToCopy = newTranscription.copyableEnhancedText ?? newTranscription.text
                _ = ClipboardManager.copyToClipboard(textToCopy)
                
                NotificationManager.shared.showNotification(
                    title: "Copied to clipboard",
                    type: .success
                )
            } catch {
                NotificationManager.shared.showNotification(
                    title: "Retry failed: \(error.localizedDescription)",
                    type: .error
                )
            }
        }
    }
}
