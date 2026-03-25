import SwiftUI

struct OnboardingModelDownloadView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject private var whisperState: WhisperState
    @Environment(\.theme) private var theme
    @State private var scale: CGFloat = 0.8
    @State private var opacity: CGFloat = 0
    @State private var pendingSelectionModelName: String? = nil
    @State private var showTutorial = false
    @State private var isMoreOptionsExpanded = false
    
    // Model Constants (single source of truth from PredefinedModels, with defensive fallback)
    private let defaultLargeModelOrder = [
        "ggml-large-v3-turbo-q5_0",
        "ggml-large-v3-turbo",
        "ggml-large-v3"
    ]

    private var resolvedLargeModelOrder: [String] {
        let order = PredefinedModels.largeV3ModelOrder
        return order.count >= 3 ? order : defaultLargeModelOrder
    }

    private var turboQuantizedName: String { resolvedLargeModelOrder[0] }
    private var turboName: String { resolvedLargeModelOrder[1] }
    private var largeV3Name: String { resolvedLargeModelOrder[2] }
    private var targetModelNames: [String] { [turboQuantizedName, turboName, largeV3Name] }
    
    // Helper to get model objects
    private func getModel(_ name: String) -> LocalModel? {
        PredefinedModels.models.first { $0.name == name } as? LocalModel
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                // Reusable background
                OnboardingBackgroundView()
                
                VStack(spacing: 32) {
                    // Title and description
                    titleSection
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    // Cards Container
                    ScrollView {
                        VStack(spacing: 24) {
                            // Primary Option: Turbo Quantized
                            if let model = getModel(turboQuantizedName) {
                                ModelCard(
                                    model: model,
                                    isRecommended: true,
                                    badgeTextKey: "onboarding_model_tag_best_value",
                                    isDownloading: isDownloading(model.name),
                                    isDownloaded: isDownloaded(model.name),
                                    isSelected: isSelected(model.name),
                                    isActionDisabled: shouldDisableAction(for: model.name),
                                    onSelect: { handleModelSelection(model) }
                                )
                            }
                            
                            // More Options
                            VStack(spacing: 16) {
                                Button(action: {
                                    withAnimation { isMoreOptionsExpanded.toggle() }
                                }) {
                                    HStack {
                                        Text(isMoreOptionsExpanded ? "Less options" : "More options")
                                            .font(theme.typography.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(theme.textSecondary)
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(theme.textSecondary)
                                            .rotationEffect(.degrees(isMoreOptionsExpanded ? 180 : 0))
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(theme.panelBackground)
                                    .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                                
                                if isMoreOptionsExpanded {
                                    VStack(spacing: 16) {
                                        if let model = getModel(turboName) {
                                            ModelCard(
                                                model: model,
                                                isRecommended: false,
                                                badgeTextKey: "onboarding_model_tag_best_quality",
                                                isDownloading: isDownloading(model.name),
                                                isDownloaded: isDownloaded(model.name),
                                                isSelected: isSelected(model.name),
                                                isActionDisabled: shouldDisableAction(for: model.name),
                                                onSelect: { handleModelSelection(model) }
                                            )
                                        }
                                        
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: min(geometry.size.width * 0.8, 700))
                    // .frame(height: 400) // Fixed height to prevent layout jumps
                    .scaleEffect(scale)
                    .opacity(opacity)
                    
                    // "Skip/Continue" footer if needed, but primary action is now auto-advance via card
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            
            if showTutorial {
                OnboardingTutorialView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear {
            animateIn()
            checkInitialState()
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey("onboarding_model_title"))
                .font(theme.typography.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
            
            VStack(spacing: 6) {
                Text(LocalizedStringKey("onboarding_model_subtitle"))
                    .font(theme.typography.body)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1
            opacity = 1
        }
    }
    
    // MARK: - Logic
    
    private func isDownloaded(_ name: String) -> Bool {
        whisperState.availableModels.contains(where: { $0.name == name })
    }

    private func isDownloading(_ name: String) -> Bool {
        if pendingSelectionModelName == name {
            return true
        }
        return whisperState.downloadProgress[name + "_main"] != nil ||
        whisperState.downloadProgress[name + "_coreml"] != nil
    }
    
    private func isSelected(_ name: String) -> Bool {
        whisperState.currentTranscriptionModel?.name == name
    }

    private var isAnyOnboardingDownloadInProgress: Bool {
        pendingSelectionModelName != nil || targetModelNames.contains(where: isDownloading)
    }

    private func shouldDisableAction(for name: String) -> Bool {
        !isDownloaded(name) && isAnyOnboardingDownloadInProgress
    }
    
    private func checkInitialState() {
        // Check if any of the target models are already valid (downloaded AND selected)
        // If the user already has one of these selected and downloaded, auto-advance
        if let current = whisperState.currentTranscriptionModel,
           targetModelNames.contains(current.name),
           isDownloaded(current.name) {
             // Already setup, auto advance
             withAnimation {
                 showTutorial = true
             }
             return
        }
        
        // If not selected but downloaded (e.g. from previous install), just exist.
        // We let the user choose in the UI.
    }
    
    private func handleModelSelection(_ model: LocalModel) {
        if isDownloaded(model.name) {
            // Already downloaded, just select and advance
            selectAndAdvance(model)
        } else {
            guard !isAnyOnboardingDownloadInProgress else { return }
            // Download then advance
            downloadAndAdvance(model)
        }
    }
    
    private func selectAndAdvance(_ model: LocalModel) {
        Task {
            // Find the actual model object in allAvailableModels to ensure we have the full metadata
            if let modelToSet = whisperState.allAvailableModels.first(where: { $0.name == model.name }) {
                await whisperState.setDefaultTranscriptionModel(modelToSet)
                await MainActor.run {
                    withAnimation {
                        showTutorial = true
                    }
                }
            }
        }
    }
    
    private func downloadAndAdvance(_ model: LocalModel) {
        pendingSelectionModelName = model.name
        
        Task {
            await whisperState.downloadModel(model)
            
            await MainActor.run {
                // Verify download success
                if pendingSelectionModelName == model.name, isDownloaded(model.name) {
                    pendingSelectionModelName = nil
                    selectAndAdvance(model)
                } else if pendingSelectionModelName == model.name {
                    pendingSelectionModelName = nil
                }
            }
        }
    }
}

// Subview for Model Card to keep main view clean
struct ModelCard: View {
    let model: LocalModel
    let isRecommended: Bool
    let badgeTextKey: String?
    let isDownloading: Bool
    let isDownloaded: Bool
    let isSelected: Bool
    let isActionDisabled: Bool
    let onSelect: () -> Void
    @EnvironmentObject private var whisperState: WhisperState // To access progress
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.displayName)
                            .font(theme.typography.headline)
                            .foregroundColor(theme.textPrimary)
                        if let badgeTextKey {
                            Text(LocalizedStringKey(badgeTextKey))
                                .font(theme.typography.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(theme.primaryButtonText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.statusPending)
                                .cornerRadius(4)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Size: \(model.size)")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.textSecondary)
                        
                        HStack(spacing: 10) {
                            Text(String(format: "Speed: %.0f%%", model.speed * 100))
                            Text(String(format: "Accuracy: %.0f%%", model.accuracy * 100))
                        }
                        .font(theme.typography.caption2)
                        .foregroundColor(theme.textSecondary)
                    }
                }
                Spacer()
                
                // Action Button
                Button(action: onSelect) {
                    Group {
                         if isDownloading {
                             ProgressView()
                                 .tint(.white)
                                 .scaleEffect(0.6)
                                 .frame(width: 80)
                         } else {
                            Text(isDownloaded ? "Select" : "Download")
                                .font(theme.typography.subheadline.weight(.bold))
                                 .foregroundColor(.white)
                                 .frame(width: 80)
                         }
                    }
                    .padding(.vertical, 8)
                    .background(theme.accentColor.opacity(isActionDisabled ? 0.55 : 1.0))
                    .cornerRadius(16)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isActionDisabled)
            }
            
            if isDownloading {
                DownloadProgressView(
                    modelName: model.name,
                    downloadProgress: whisperState.downloadProgress
                )
            }
        }
        .padding(16)
        .background(theme.inputBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isRecommended ? theme.accentColor : theme.panelBorder, lineWidth: isRecommended ? 2 : 1)
        )
    }
}
