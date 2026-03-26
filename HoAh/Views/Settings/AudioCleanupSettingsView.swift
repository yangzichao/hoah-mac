import SwiftUI
import SwiftData

struct AudioCleanupSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @EnvironmentObject private var whisperState: WhisperState
    @Environment(\.theme) private var theme
    @State private var isPerformingCleanup = false
    @State private var isShowingConfirmation = false
    @State private var cleanupInfo: (fileCount: Int, totalSize: Int64, transcriptions: [Transcription]) = (0, 0, [])
    @State private var showResultAlert = false
    @State private var cleanupResult: (deletedCount: Int, errorCount: Int) = (0, 0)
    @State private var showTranscriptCleanupResult = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Control how HoAh handles your transcription data and audio recordings for privacy and storage management.")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            SettingsToggleRow("Automatically delete transcript history", isOn: $appSettings.isTranscriptionCleanupEnabled)
                .padding(.vertical, 4)
            
            if appSettings.isTranscriptionCleanupEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Delete transcripts older than")
                        Spacer()
                        Menu {
                            Button("Immediately") { appSettings.transcriptionRetentionMinutes = 0 }
                            Button("1 hour") { appSettings.transcriptionRetentionMinutes = 60 }
                            Button("1 day") { appSettings.transcriptionRetentionMinutes = 24 * 60 }
                            Button("3 days") { appSettings.transcriptionRetentionMinutes = 3 * 24 * 60 }
                            Button("7 days") { appSettings.transcriptionRetentionMinutes = 7 * 24 * 60 }
                            Button("30 days") { appSettings.transcriptionRetentionMinutes = 30 * 24 * 60 }
                        } label: {
                            Text(getTranscriptionRetentionLabel(appSettings.transcriptionRetentionMinutes))
                                .foregroundColor(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .menuStyle(.borderedButton)
                        .fixedSize()
                    }

                    Text("Older transcripts will be deleted automatically based on your selection.")
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)

                    Button(action: {
                        Task {
                            await TranscriptionAutoCleanupService.shared.runManualCleanup(modelContext: whisperState.modelContext)
                            await MainActor.run {
                                showTranscriptCleanupResult = true
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash.circle")
                            Text("Run Transcript Cleanup Now")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .alert("Transcript Cleanup", isPresented: $showTranscriptCleanupResult) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Cleanup triggered. Old transcripts are cleaned up according to your retention setting.")
                    }
                }
                .padding(.vertical, 4)
            }

            if !appSettings.isTranscriptionCleanupEnabled {
                SettingsToggleRow("Enable automatic audio cleanup", isOn: $appSettings.isAudioCleanupEnabled)
                    .padding(.vertical, 4)
            }

            if appSettings.isAudioCleanupEnabled && !appSettings.isTranscriptionCleanupEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Keep audio files for")
                        Spacer()
                        Menu {
                            Button("1 day") { appSettings.audioRetentionPeriod = 1 }
                            Button("3 days") { appSettings.audioRetentionPeriod = 3 }
                            Button("7 days") { appSettings.audioRetentionPeriod = 7 }
                            Button("14 days") { appSettings.audioRetentionPeriod = 14 }
                            Button("30 days") { appSettings.audioRetentionPeriod = 30 }
                        } label: {
                            Text(getAudioRetentionLabel(appSettings.audioRetentionPeriod))
                                .foregroundColor(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .menuStyle(.borderedButton)
                        .fixedSize()
                    }
                    
                    Text("Audio files older than the selected period will be automatically deleted, while keeping the text transcripts intact.")
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(.vertical, 4)
                
                Button(action: {
                    // Start by analyzing what would be cleaned up
                    Task {
                        // Update UI state
                        await MainActor.run {
                            isPerformingCleanup = true
                        }
                        
                        // Get cleanup info
                        let info = await AudioCleanupManager.shared.getCleanupInfo(modelContext: whisperState.modelContext)
                        
                        // Update UI with results
                        await MainActor.run {
                            cleanupInfo = info
                            isPerformingCleanup = false
                            isShowingConfirmation = true
                        }
                    }
                }) {
                    HStack {
                        if isPerformingCleanup {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isPerformingCleanup ? "Analyzing..." : "Run Cleanup Now")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isPerformingCleanup)
                .alert(NSLocalizedString("Audio Cleanup", comment: ""), isPresented: $isShowingConfirmation) {
                    Button(LocalizedStringKey("Cancel"), role: .cancel) { }
                    
                    if cleanupInfo.fileCount > 0 {
                        Button(String(format: NSLocalizedString("Delete %lld Files", comment: ""), cleanupInfo.fileCount), role: .destructive) {
                            Task {
                                // Update UI state
                                await MainActor.run {
                                    isPerformingCleanup = true
                                }
                                
                                // Perform cleanup
                                let result = await AudioCleanupManager.shared.runCleanupForTranscriptions(
                                    modelContext: whisperState.modelContext, 
                                    transcriptions: cleanupInfo.transcriptions
                                )
                                
                                // Update UI with results
                                await MainActor.run {
                                    cleanupResult = result
                                    isPerformingCleanup = false
                                    showResultAlert = true
                                }
                            }
                        }
                    }
                } message: {
                    VStack(alignment: .leading, spacing: 8) {
                        if cleanupInfo.fileCount > 0 {
                            Text(String(format: NSLocalizedString("This will delete %lld audio files older than %lld days.", comment: ""), cleanupInfo.fileCount, appSettings.audioRetentionPeriod))
                            Text(String(format: NSLocalizedString("Total size to be freed: %@", comment: ""), AudioCleanupManager.shared.formatFileSize(cleanupInfo.totalSize)))
                            Text(LocalizedStringKey("The text transcripts will be preserved."))
                        } else {
                            Text(String(format: NSLocalizedString("No audio files found that are older than %lld days.", comment: ""), appSettings.audioRetentionPeriod))
                        }
                    }
                }
                .alert(NSLocalizedString("Cleanup Complete", comment: ""), isPresented: $showResultAlert) {
                    Button(LocalizedStringKey("OK"), role: .cancel) { }
                } message: {
                    if cleanupResult.errorCount > 0 {
                        Text(String(format: NSLocalizedString("Successfully deleted %lld audio files. Failed to delete %lld files.", comment: ""), cleanupResult.deletedCount, cleanupResult.errorCount))
                    } else {
                        Text(String(format: NSLocalizedString("Successfully deleted %lld audio files.", comment: ""), cleanupResult.deletedCount))
                    }
                }
            }
        }
        .onChange(of: appSettings.isTranscriptionCleanupEnabled) { _, newValue in
            if newValue {
                AudioCleanupManager.shared.stopAutomaticCleanup()
            } else if appSettings.isAudioCleanupEnabled {
                AudioCleanupManager.shared.startAutomaticCleanup(modelContext: whisperState.modelContext)
            }
        }
    }
    
    private func getTranscriptionRetentionLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "Immediately"
        case 60: return "1 hour"
        case 24 * 60: return "1 day"
        case 3 * 24 * 60: return "3 days"
        case 7 * 24 * 60: return "7 days"
        case 30 * 24 * 60: return "30 days"
        default: return "\(minutes / (24*60)) days"
        }
    }

    private func getAudioRetentionLabel(_ days: Int) -> String {
        return "\(days) day\(days > 1 ? "s" : "")"
    }
} 
