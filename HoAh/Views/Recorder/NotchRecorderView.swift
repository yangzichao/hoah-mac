import SwiftUI

struct NotchRecorderView: View {
    @ObservedObject var whisperState: WhisperState
    @ObservedObject var recorder: Recorder
    @EnvironmentObject var windowManager: NotchWindowManager
    @State private var isHovering = false
    @State private var activePopover: ActivePopoverState = .none
    @Environment(\.theme) private var theme
    
    @EnvironmentObject private var enhancementService: AIEnhancementService
    
    @State private var neonPulse: Bool = false // For Cyberpunk animation
    
    /// Helper to get theme type from theme.id
    private var themeType: UITheme { theme.id }

    private var shouldShowLiveTranscriptStatus: Bool {
        whisperState.isStreamingSessionActive &&
        (whisperState.recordingState == .recording || whisperState.recordingState == .finishing) &&
        (!whisperState.liveTranscriptPreview.isEmpty || whisperState.liveStreamingError != nil)
    }
    
    private var menuBarHeight: CGFloat {
        if let screen = NSScreen.main {
            if screen.safeAreaInsets.top > 0 {
                return screen.safeAreaInsets.top
            }
            return NSApplication.shared.mainMenu?.menuBarHeight ?? NSStatusBar.system.thickness
        }
        return NSStatusBar.system.thickness
    }
    
    private var exactNotchWidth: CGFloat {
        if let screen = NSScreen.main {
            if screen.safeAreaInsets.left > 0 {
                return screen.safeAreaInsets.left * 2
            }
            return 200
        }
        return 200
    }
    
    private var leftSection: some View {
        HStack(spacing: 12) {
            RecorderPromptButton(
                activePopover: $activePopover,
                buttonSize: 22,
                padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            )

            RecorderHistoryButton(
                activePopover: $activePopover,
                whisperState: whisperState,
                buttonSize: 22,
                padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            )

            Spacer()
        }
        .frame(width: 64)
        .padding(.leading, 16)
    }
    
    private var centerSection: some View {
        Group {
            if shouldShowLiveTranscriptStatus {
                RecorderLiveTranscriptView(whisperState: whisperState)
                    .frame(width: exactNotchWidth)
                    .contentShape(Rectangle())
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: exactNotchWidth)
                    .contentShape(Rectangle())
            }
        }
    }
    
    private var rightSection: some View {
        HStack(spacing: 8) {
            Spacer()
            statusDisplay
        }
        .frame(width: 64)
        .padding(.trailing, 16)
    }
    
    private var statusDisplay: some View {
        RecorderStatusDisplay(
            currentState: whisperState.recordingState,
            audioMeter: recorder.audioMeter,
            menuBarHeight: menuBarHeight,
            recordingMode: whisperState.recordingMode
        )
        .frame(width: 70)
        .padding(.trailing, 8)
    }
    
    // MARK: - Theme Specifics
    
    @ViewBuilder
    private var backgroundView: some View {
        switch themeType {
        case .liquidGlass:
            ZStack {
                VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
            }
        case .cyberpunk:
            ZStack {
                // Purple-Black Gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.03, blue: 0.15),
                        Color(red: 0.03, green: 0.02, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Scanline
                VStack(spacing: 2) {
                    ForEach(0..<15, id: \.self) { _ in
                        Rectangle().fill(Color.white.opacity(0.02)).frame(height: 1)
                        Spacer().frame(height: 2)
                    }
                }
            }
        case .vintage:
            ZStack {
                Color(red: 0.94, green: 0.91, blue: 0.85) // Warm paper
                // Grain
                GeometryReader { geometry in
                    Path { path in
                        let w = geometry.size.width
                        let h = geometry.size.height
                        var seed = 42
                        for _ in 0..<20 {
                            seed = (seed * 1664525 + 1013904223) % 4294967296
                            let x = Double(seed % Int(w))
                            seed = (seed * 1664525 + 1013904223) % 4294967296
                            let y = Double(seed % Int(h))
                            path.addEllipse(in: CGRect(x: x, y: y, width: 1, height: 1))
                        }
                    }
                    .fill(Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.1))
                }
            }
        case .basic:
            theme.backgroundBase
        }
    }
    
    @ViewBuilder
    private var borderView: some View {
        switch themeType {
        case .liquidGlass:
            NotchShape(cornerRadius: 10)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.5
                )
        case .cyberpunk:
            ZStack {
                // Neon Stroke
                NotchShape(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.85, blue: 0.9), // Cyan
                                Color(red: 0.8, green: 0.0, blue: 0.6)  // Pink
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
                
                // Pulse
                NotchShape(cornerRadius: 10)
                    .stroke(Color(red: 0.0, green: 0.85, blue: 0.9).opacity(neonPulse ? 0.5 : 0.1), lineWidth: 1)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { neonPulse = true }
            }
        case .vintage:
            NotchShape(cornerRadius: 10)
                .stroke(Color(red: 0.6, green: 0.25, blue: 0.15).opacity(0.6), lineWidth: 1)
        case .basic:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var shadowLayer: some View {
        switch themeType {
        case .cyberpunk:
             ZStack {
                // Cyan glow (blur clipped)
                NotchShape(cornerRadius: 10)
                    .fill(Color(red: 0.0, green: 0.85, blue: 0.9).opacity(0.3))
                    .blur(radius: 6)
                
                // Pink glow (offset down)
                NotchShape(cornerRadius: 10)
                    .fill(Color(red: 0.8, green: 0.0, blue: 0.6).opacity(0.2))
                    .blur(radius: 10)
                    .offset(y: 3)
            }
             .clipShape(NotchShape(cornerRadius: 10).offset(y: 4).scale(1.2)) // Allow glow to spill downwards only
        case .vintage:
            NotchShape(cornerRadius: 10)
                .fill(Color.black.opacity(0.15))
                .blur(radius: 4)
                .offset(y: 2)
        default:
            EmptyView()
        }
    }

    var body: some View {
        Group {
            if windowManager.isVisible {
                ZStack {
                    // Shadow Layer (Behind Content)
                    shadowLayer
                    
                    // Main Content
                    HStack(spacing: 0) {
                        leftSection
                        centerSection
                        rightSection
                    }
                    .frame(height: menuBarHeight)
                    .background(backgroundView)
                    .mask {
                        NotchShape(cornerRadius: 10)
                    }
                    .overlay(borderView)
                    .clipped() // Ensure content stays within frame for basic themes, but we have mask anyway
                }
                .onHover { hovering in
                    isHovering = hovering
                }
                .opacity(windowManager.isVisible ? 1 : 0)
            }
        }
    }
}
