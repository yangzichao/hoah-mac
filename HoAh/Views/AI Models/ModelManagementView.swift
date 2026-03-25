import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum ModelFilter: String, CaseIterable, Identifiable {
    case recommended = "Recommended"
    case local = "Local"
    case cloud = "Cloud Batch"
    case cloudStreaming = "Cloud Streaming"
    var id: String { self.rawValue }
}

/// ModelManagementView manages transcription models (speech-to-text).
/// For AI enhancement providers (text post-processing), see EnhancementSettingsView.
struct ModelManagementView: View {
    @ObservedObject var whisperState: WhisperState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var whisperPrompt = WhisperPrompt()
    @ObservedObject private var warmupCoordinator = WhisperModelWarmupCoordinator.shared
    @Environment(\.theme) private var theme

    @State private var selectedFilter: ModelFilter = .recommended
    @State private var isShowingSettings = false
    
    // State for the unified alert
    @State private var isShowingDeleteAlert = false
    @State private var alertTitle: LocalizedStringKey = ""
    @State private var alertMessage = ""
    @State private var deleteActionClosure: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: "waveform")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.statusInfo)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dictation Models")
                            .font(theme.typography.title2)
                        Text("dictation_models_description")
                            .font(theme.typography.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                defaultModelSection
                languageSelectionSection
                availableModelsSection
            }
            .padding(32)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(theme.controlBackground)
        .alert(isPresented: $isShowingDeleteAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                primaryButton: .destructive(Text("Delete"), action: deleteActionClosure),
                secondaryButton: .cancel()
            )
        }
    }
    
    private var defaultModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Dictation Model")
                .font(theme.typography.headline)
                .foregroundColor(theme.textSecondary)
            Text(whisperState.currentTranscriptionModel?.displayName ?? String(localized: "No model selected"))
                .font(theme.typography.title2)
                .fontWeight(.bold)
            
            // Show recommendation when no model is selected
            if whisperState.currentTranscriptionModel == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 4)
                    Text("Our Recommendations")
                        .font(theme.typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textSecondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                                .foregroundColor(theme.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                (Text("For local processing")
                                    .fontWeight(.medium)
                                    .foregroundColor(theme.textPrimary)
                                + Text(": ")
                                    .foregroundColor(theme.textSecondary)
                                + Text("Large v3 Turbo")
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.accentColor))
                                
                                Text("Local Model Description")
                                    .font(theme.typography.caption2)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        .font(theme.typography.caption)
                        
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                                .foregroundColor(theme.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                (Text("For cloud streaming")
                                    .fontWeight(.medium)
                                    .foregroundColor(theme.textPrimary)
                                + Text(": ")
                                    .foregroundColor(theme.textSecondary)
                                + Text("Scribe v2 Realtime (ElevenLabs)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.accentColor))
                                
                                Text("Cloud Model Description")
                                    .font(theme.typography.caption2)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        .font(theme.typography.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
        .cornerRadius(10)
    }
    
    private var languageSelectionSection: some View {
        LanguageSelectionView(whisperState: whisperState, displayMode: .full, whisperPrompt: whisperPrompt)
    }
    
    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Modern compact pill switcher
                HStack(spacing: 12) {
                    ForEach(availableFilters, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedFilter = filter
                                isShowingSettings = false
                            }
                        }) {
                            Text(LocalizedStringKey(filter.rawValue))
                                .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .medium))
                                .foregroundColor(selectedFilter == filter ? theme.textPrimary : theme.textPrimary.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    CardBackground(isSelected: selectedFilter == filter, cornerRadius: 22)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingSettings.toggle()
                    }
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isShowingSettings ? theme.accentColor : theme.textPrimary.opacity(0.7))
                        .padding(12)
                        .background(
                            CardBackground(isSelected: isShowingSettings, cornerRadius: 22)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 12)
            
            if isShowingSettings {
                ModelSettingsView(whisperPrompt: whisperPrompt)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredModels, id: \.id) { model in
                        let isWarming = (model as? LocalModel).map { localModel in
                            warmupCoordinator.isWarming(modelNamed: localModel.name)
                        } ?? false

                        ModelCardRowView(
                            model: model,
                            whisperState: whisperState, 
                            isDownloaded: whisperState.availableModels.contains { $0.name == model.name },
                            isCurrent: whisperState.currentTranscriptionModel?.name == model.name,
                            downloadProgress: whisperState.downloadProgress,
                            modelURL: whisperState.availableModels.first { $0.name == model.name }?.url,
                            isWarming: isWarming,
                            deleteAction: {
                                if let downloadedModel = whisperState.availableModels.first(where: { $0.name == model.name }) {
                                    alertTitle = "Delete Model"
                                    alertMessage = String(
                                        format: String(localized: "Are you sure you want to delete the model '%@'?"),
                                        downloadedModel.name
                                    )
                                    deleteActionClosure = {
                                        Task {
                                            await whisperState.deleteModel(downloadedModel)
                                        }
                                    }
                                    isShowingDeleteAlert = true
                                }
                            },
                            setDefaultAction: {
                                Task {
                                    await whisperState.setDefaultTranscriptionModel(model)
                                }
                            },
                            downloadAction: {
                                if let localModel = model as? LocalModel {
                                    Task { await whisperState.downloadModel(localModel) }
                                }
                            },
                            editAction: nil
                        )
                    }
                    

                }
            }
        }
        .padding()
    }

    private var availableFilters: [ModelFilter] {
        ModelFilter.allCases.filter { filter in
            switch filter {
            case .recommended, .local:
                return true
            case .cloud:
                return visibleDictationModels.contains(where: isStandardCloudModel)
            case .cloudStreaming:
                return visibleDictationModels.contains(where: isStreamingCloudModel)
            }
        }
    }

    private var visibleDictationModels: [any TranscriptionModel] {
        whisperState.allAvailableModels
    }

    private var filteredModels: [any TranscriptionModel] {
        switch selectedFilter {
        case .recommended:
            return visibleDictationModels.filter {
                let recommendedNames = ["ggml-large-v3-turbo", "scribe_v2"]
                return recommendedNames.contains($0.name)
            }.sorted { model1, model2 in
                let recommendedOrder = ["ggml-large-v3-turbo", "scribe_v2"]
                let index1 = recommendedOrder.firstIndex(of: model1.name) ?? Int.max
                let index2 = recommendedOrder.firstIndex(of: model2.name) ?? Int.max
                return index1 < index2
            }
        case .local:
            return visibleDictationModels.filter { $0.provider == .local || $0.provider == .nativeApple }
        case .cloud:
            return visibleDictationModels.filter(isStandardCloudModel)
        case .cloudStreaming:
            return visibleDictationModels.filter(isStreamingCloudModel)
        }
    }

    private func isStreamingCloudModel(_ model: any TranscriptionModel) -> Bool {
        model.usesRealtimeStreaming
    }

    private func isStandardCloudModel(_ model: any TranscriptionModel) -> Bool {
        model.isCloudBatchModel
    }

}
