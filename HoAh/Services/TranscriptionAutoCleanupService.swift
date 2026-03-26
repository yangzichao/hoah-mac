import Foundation
import SwiftData
import OSLog

class TranscriptionAutoCleanupService {
    static let shared = TranscriptionAutoCleanupService()

    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "TranscriptionAutoCleanupService")
    private var modelContext: ModelContext?

    private let keyIsEnabled = "IsTranscriptionCleanupEnabled"
    private let keyRetentionMinutes = "TranscriptionRetentionMinutes"

    private let defaultRetentionMinutes: Int = 24 * 60

    private init() {}

    func startMonitoring(modelContext: ModelContext) {
        self.modelContext = modelContext

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTranscriptionCompleted(_:)),
            name: .transcriptionCompleted,
            object: nil
        )

        if AppSettingsSnapshot.current().isTranscriptionCleanupEnabled {
            
            Task { [weak self] in
                guard let self = self, let modelContext = self.modelContext else { return }
                await self.sweepOldTranscriptions(modelContext: modelContext)
            }
        } else {}
    }

    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self, name: .transcriptionCompleted, object: nil)
    }

    func runManualCleanup(modelContext: ModelContext) async {
        await sweepOldTranscriptions(modelContext: modelContext)
    }

    @objc private func handleTranscriptionCompleted(_ notification: Notification) {
        let snapshot = AppSettingsSnapshot.current()
        let isEnabled = snapshot.isTranscriptionCleanupEnabled
        guard isEnabled else { return }

        let minutes = snapshot.transcriptionRetentionMinutes
        if minutes > 0 {
            // Trigger a sweep based on the retention window
            if let modelContext = self.modelContext {
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.sweepOldTranscriptions(modelContext: modelContext)
                }
            }
            return
        }

        guard let transcription = notification.object as? Transcription,
              let modelContext = self.modelContext else {
            logger.error("Invalid transcription or missing model context")
            return
        }

        if let urlString = transcription.audioFileURL,
           let url = URL(string: urlString) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                logger.error("Failed to delete audio file: \(error.localizedDescription)")
            }
        }

        modelContext.delete(transcription)

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save after transcription deletion: \(error.localizedDescription)")
        }
    }

    private func sweepOldTranscriptions(modelContext: ModelContext) async {
        let snapshot = AppSettingsSnapshot.current()
        guard snapshot.isTranscriptionCleanupEnabled else {
            return
        }

        let effectiveMinutes = max(snapshot.transcriptionRetentionMinutes, 0)

        let cutoffDate = Date().addingTimeInterval(TimeInterval(-effectiveMinutes * 60))

        do {
            try await MainActor.run {
                // Ensure all model context operations happen on the main thread
                let descriptor = FetchDescriptor<Transcription>(
                    predicate: #Predicate<Transcription> { transcription in
                        transcription.timestamp < cutoffDate
                    }
                )
                
                // Perform fetch on main actor where modelContext is bound
                let items = try modelContext.fetch(descriptor)
                var deletedCount = 0
                for transcription in items {
                    // Remove audio file if present
                    if let urlString = transcription.audioFileURL,
                       let url = URL(string: urlString),
                       FileManager.default.fileExists(atPath: url.path) {
                        try? FileManager.default.removeItem(at: url)
                    }
                    modelContext.delete(transcription)
                    deletedCount += 1
                }
                if deletedCount > 0 { try modelContext.save() }
            }
        } catch {
            logger.error("Failed during transcription cleanup: \(error.localizedDescription)")
        }
    }
}
