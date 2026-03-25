import SwiftUI
import SwiftData

// MARK: - Shared Popover State
enum ActivePopoverState {
    case none
    case enhancement
    case history
}

// MARK: - Generic Toggle Button Component
struct RecorderToggleButton: View {
    let isEnabled: Bool
    let icon: String
    let color: Color
    let disabled: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    init(isEnabled: Bool, icon: String, color: Color, disabled: Bool = false, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.icon = icon
        self.color = color
        self.disabled = disabled
        self.action = action
    }
    
    private var isEmoji: Bool {
        return !icon.contains(".") && !icon.contains("-") && icon.unicodeScalars.contains { !$0.isASCII }
    }
    
    var body: some View {
        Button(action: action) {
            Group {
                if isEmoji {
                    Text(icon)
                        .font(.system(size: 14))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                }
            }
            // Use the passed color when enabled to provide visual feedback
            .foregroundColor(disabled ? theme.textMuted.opacity(0.3) : (isEnabled ? color : theme.textMuted))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
    }
}

// MARK: - Generic Record Button Component
struct RecorderRecordButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 25, height: 25)
                
                if isProcessing {
                    ProcessingIndicator(color: theme.textPrimary)
                        .frame(width: 16, height: 16)
                } else if isRecording {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.textPrimary)
                        .frame(width: 9, height: 9)
                } else {
                    Circle()
                        .fill(theme.textPrimary)
                        .frame(width: 9, height: 9)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isProcessing)
    }
    
    private var buttonColor: Color {
        if isProcessing {
            return theme.textMuted.opacity(0.6)
        } else if isRecording {
            return theme.statusError
        } else {
            return theme.textMuted.opacity(0.7)
        }
    }
}

// MARK: - Processing Indicator Component
struct ProcessingIndicator: View {
    @State private var rotation: Double = 0
    let color: Color
    
    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(color, lineWidth: 1.7)
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Progress Animation Component
struct ProgressAnimation: View {
    @State private var currentDot = 0
    @State private var timer: Timer?
    let animationSpeed: Double
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(theme.textPrimary.opacity(index <= currentDot ? 0.8 : 0.2))
                    .frame(width: 3.5, height: 3.5)
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: animationSpeed, repeats: true) { _ in
                currentDot = (currentDot + 1) % 7
                if currentDot >= 5 { currentDot = -1 }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Prompt Button Component
struct RecorderPromptButton: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Binding var activePopover: ActivePopoverState
    let buttonSize: CGFloat
    let padding: EdgeInsets
    @State private var isHoveringEnhancement: Bool = false
    @State private var isHoveringEnhancementPopover: Bool = false
    @State private var enhancementDismissWorkItem: DispatchWorkItem?
    @Environment(\.theme) private var theme

    init(activePopover: Binding<ActivePopoverState>, buttonSize: CGFloat = 28, padding: EdgeInsets = EdgeInsets(top: 0, leading: 7, bottom: 0, trailing: 0)) {
        self._activePopover = activePopover
        self.buttonSize = buttonSize
        self.padding = padding
    }
    
    private var isPresentedBinding: Binding<Bool> {
        Binding(
            get: { activePopover == .enhancement },
            set: { if !$0 { activePopover = .none } }
        )
    }
    
    var body: some View {
        RecorderToggleButton(
            isEnabled: appSettings.isAIEnhancementEnabled,
            icon: enhancementService.activePrompt?.icon ?? enhancementService.activePrompts.first(where: { $0.id == PredefinedPrompts.defaultPromptId })?.icon ?? "checkmark.seal.fill",
            color: theme.statusInfo,
            disabled: false
        ) {
            if appSettings.isAIEnhancementEnabled {
                activePopover = activePopover == .enhancement ? .none : .enhancement
            } else {
                // Try to enable AI enhancement
                if appSettings.tryEnableAIEnhancement() {
                    activePopover = .enhancement
                } else {
                    // Show notification to guide user to set up AI
                    NotificationManager.shared.showNotification(
                        title: NSLocalizedString("Please configure AI in Settings → Enhancement", comment: ""),
                        type: .warning
                    )
                }
            }
        }
        .frame(width: buttonSize)
        .padding(padding)
        .onHover {
            isHoveringEnhancement = $0
            syncEnhancementPopoverVisibility()
        }
        .popover(isPresented: isPresentedBinding, arrowEdge: .bottom) {
            EnhancementPromptPopover()
                .environmentObject(enhancementService)
                .environmentObject(appSettings)
                .onHover {
                    isHoveringEnhancementPopover = $0
                    syncEnhancementPopoverVisibility()
                }
        }
    }

    private func syncEnhancementPopoverVisibility() {
        let shouldShow = isHoveringEnhancement || isHoveringEnhancementPopover
        if shouldShow {
            enhancementDismissWorkItem?.cancel()
            enhancementDismissWorkItem = nil
            activePopover = .enhancement
        } else {
            enhancementDismissWorkItem?.cancel()
            let work = DispatchWorkItem { [activePopoverBinding = $activePopover] in
                if activePopoverBinding.wrappedValue == .enhancement {
                    activePopoverBinding.wrappedValue = .none
                }
            }
            enhancementDismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }
}

// MARK: - Recent History Button Component
struct RecorderHistoryButton: View {
    @Environment(\.modelContext) private var modelContext
    let whisperState: WhisperState
    @Binding var activePopover: ActivePopoverState
    let buttonSize: CGFloat
    let padding: EdgeInsets
    @State private var isHoveringHistory: Bool = false
    @State private var isHoveringHistoryPopover: Bool = false
    @State private var historyDismissWorkItem: DispatchWorkItem?
    @Environment(\.theme) private var theme
    
    init(
        activePopover: Binding<ActivePopoverState>,
        whisperState: WhisperState,
        buttonSize: CGFloat = 28,
        padding: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 7)
    ) {
        self._activePopover = activePopover
        self.whisperState = whisperState
        self.buttonSize = buttonSize
        self.padding = padding
    }
    
    private var isPresentedBinding: Binding<Bool> {
        Binding(
            get: { activePopover == .history },
            set: { if !$0 { activePopover = .none } }
        )
    }
    
    var body: some View {
        RecorderToggleButton(
            isEnabled: true, // Always colorful when open or enabled
            icon: "doc.on.clipboard",
            color: theme.statusWarning,
            disabled: false
        ) {
            withAnimation(.snappy) {
                activePopover = activePopover == .history ? .none : .history
            }
        }
        .frame(width: buttonSize)
        .padding(padding)
        .onHover {
            isHoveringHistory = $0
            syncHistoryPopoverVisibility()
        }
        .popover(isPresented: isPresentedBinding, arrowEdge: .bottom) {
            RecentTranscriptionsPopover(
                modelContext: modelContext,
                whisperState: whisperState,
                dismissPopover: { activePopover = .none }
            )
            .onHover {
                isHoveringHistoryPopover = $0
                syncHistoryPopoverVisibility()
            }
        }
    }
    
    private func syncHistoryPopoverVisibility() {
        let shouldShow = isHoveringHistory || isHoveringHistoryPopover
        if shouldShow {
            historyDismissWorkItem?.cancel()
            historyDismissWorkItem = nil
            activePopover = .history
        } else {
            historyDismissWorkItem?.cancel()
            let work = DispatchWorkItem { [activePopoverBinding = $activePopover] in
                if activePopoverBinding.wrappedValue == .history {
                    activePopoverBinding.wrappedValue = .none
                }
            }
            historyDismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }
}

// MARK: - Recent Transcriptions Popover
struct RecentTranscriptionsPopover: View {
    let modelContext: ModelContext
    let whisperState: WhisperState
    let dismissPopover: () -> Void
    @Environment(\.theme) private var theme
    
    @Query(sort: \Transcription.timestamp, order: .reverse) private var allTranscriptions: [Transcription]
    
    var recentTranscriptions: [Transcription] {
        Array(allTranscriptions.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textPrimary.opacity(0.9))
                
                Text(LocalizedStringKey("recorder_recent_header"))
                    .font(theme.typography.headline)
                    .foregroundColor(theme.textPrimary.opacity(0.9))
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
                .background(theme.panelBorder)
            
            if recentTranscriptions.isEmpty {
                Text(LocalizedStringKey("recorder_recent_empty"))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textMuted)
                    .padding()
            } else {
                // Fixed list of recent 3 items, NO SCROLL
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recentTranscriptions) { transcription in
                        RecentTranscriptionRow(
                            transcription: transcription,
                            displayText: displayText(for: transcription),
                            isLatest: transcription.id == recentTranscriptions.first?.id,
                            onSelect: { handleSelection(transcription) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 250)
        // Matches EnhancementPromptPopover style: subtle vertical padding before background
        .padding(.vertical, 8) 
        .background(theme.backgroundBase)
        .environment(\.colorScheme, .dark)
    }
    
    private func displayText(for transcription: Transcription) -> String {
        let text = transcription.enhancedText?.isEmpty == false ? transcription.enhancedText! : transcription.text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("recorder_recent_empty", comment: "") : trimmed
    }
    
    private func handleSelection(_ transcription: Transcription) {
        let text = transcription.enhancedText?.isEmpty == false ? transcription.enhancedText! : transcription.text
        let success = ClipboardManager.copyToClipboard(text)
        
        Task { @MainActor in
            dismissPopover()
            
            if success {
                NotificationManager.shared.showNotification(
                    title: NSLocalizedString("recorder_recent_copied", comment: ""),
                    type: .success
                )
            } else {
                NotificationManager.shared.showNotification(
                    title: NSLocalizedString("recorder_recent_copy_failed", comment: ""),
                    type: .error
                )
            }
            
            if whisperState.recordingState != .idle {
                await whisperState.cancelRecording()
            }
        }
    }
}

private struct RecentTranscriptionRow: View {
    let transcription: Transcription
    let displayText: String
    let isLatest: Bool
    let onSelect: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                // Icon
                Image(systemName: isLatest ? "doc.on.clipboard.fill" : "doc.on.clipboard")
                    .font(.system(size: 14))
                    .foregroundColor(isLatest ? theme.textPrimary : theme.textMuted)
                    .frame(width: 16, alignment: .center)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayText)
                        .font(.system(size: 13))
                        .foregroundColor(isLatest ? theme.textPrimary : theme.textPrimary.opacity(0.9))
                        .lineLimit(2) // Limit lines to keep it compact
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isLatest {
                    Image(systemName: "checkmark.circle.fill")
                         .font(.system(size: 10))
                         .foregroundColor(theme.statusSuccess.opacity(0.8))
                         .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isLatest ? theme.panelBackground : Color.clear)
        .cornerRadius(4)
        .help(isLatest ? LocalizedStringKey("recorder_recent_copy_latest") : LocalizedStringKey("recorder_recent_copy_action"))
    }
}

// MARK: - Status Display Component
struct RecorderStatusDisplay: View {
    let currentState: RecordingState
    let audioMeter: AudioMeter
    let menuBarHeight: CGFloat?
    @Environment(\.theme) private var theme
    
    init(currentState: RecordingState, audioMeter: AudioMeter, menuBarHeight: CGFloat? = nil) {
        self.currentState = currentState
        self.audioMeter = audioMeter
        self.menuBarHeight = menuBarHeight
    }
    
    var body: some View {
        Group {
            if currentState == .enhancing {
                VStack(spacing: 2) {
                    Text(LocalizedStringKey("Enhancing"))
                        .foregroundColor(theme.textPrimary)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    ProgressAnimation(animationSpeed: 0.15)
                }
            } else if currentState == .finishing {
                VStack(spacing: 2) {
                    Text(LocalizedStringKey("Finishing"))
                        .foregroundColor(theme.textPrimary)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    ProgressAnimation(animationSpeed: 0.1)
                }
            } else if currentState == .transcribing {
                VStack(spacing: 2) {
                    Text(LocalizedStringKey("Transcribing"))
                        .foregroundColor(theme.textPrimary)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    ProgressAnimation(animationSpeed: 0.12)
                }
            } else if currentState == .recording {
                AudioVisualizer(
                    audioMeter: audioMeter,
                    color: theme.textPrimary,
                    isActive: currentState == .recording
                )
                .scaleEffect(y: menuBarHeight != nil ? min(1.0, (menuBarHeight! - 8) / 25) : 1.0, anchor: .center)
            } else {
                StaticVisualizer(color: theme.textPrimary)
                    .scaleEffect(y: menuBarHeight != nil ? min(1.0, (menuBarHeight! - 8) / 25) : 1.0, anchor: .center)
            }
        }
    }
}

struct RecorderLiveTranscriptView: View {
    @ObservedObject var whisperState: WhisperState
    @Environment(\.theme) private var theme

    private var committedText: String {
        whisperState.liveCommittedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var partialText: String {
        whisperState.livePartialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasLiveText: Bool {
        !committedText.isEmpty || !partialText.isEmpty
    }

    private var isFinishing: Bool {
        whisperState.recordingState == .finishing
    }

    var body: some View {
        Group {
            if let error = whisperState.liveStreamingError,
               !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               whisperState.isStreamingSessionActive {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.statusError)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if hasLiveText && whisperState.isStreamingSessionActive {
                HStack(spacing: 0) {
                    if isFinishing {
                        HStack(spacing: 4) {
                            ProcessingIndicator(color: theme.textSecondary)
                                .frame(width: 10, height: 10)
                            Text(LocalizedStringKey("Finishing"))
                                .foregroundColor(theme.textSecondary)
                            Text(" · ")
                                .foregroundColor(theme.textSecondary.opacity(0.8))
                        }
                    }

                    if !committedText.isEmpty {
                        Text(committedText + (partialText.isEmpty ? "" : " "))
                            .foregroundColor(theme.textPrimary)
                    }

                    if !partialText.isEmpty {
                        Text(partialText)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.head)
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
