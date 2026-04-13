import SwiftUI

struct MiniRecorderView: View {
    @ObservedObject var whisperState: WhisperState
    @ObservedObject var recorder: Recorder
    @EnvironmentObject var windowManager: MiniWindowManager
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.theme) private var theme
    
    @State private var activePopover: ActivePopoverState = .none
    @State private var neonPulse: Bool = false // For Cyberpunk animation
    
    /// Helper to get theme type from theme.id
    private var themeType: UITheme { theme.id }

    private var usesRealtimeStreaming: Bool {
        whisperState.currentTranscriptionModel?.usesRealtimeStreaming == true
    }

    private var shouldShowLiveTranscriptStatus: Bool {
        whisperState.isStreamingSessionActive &&
        (whisperState.recordingState == .recording || whisperState.recordingState == .finishing) &&
        (!whisperState.liveTranscriptPreview.isEmpty || whisperState.liveStreamingError != nil)
    }

    private var sideButtonSize: CGFloat {
        usesRealtimeStreaming ? 22 : 28
    }

    private var sidePaddingHorizontal: CGFloat {
        usesRealtimeStreaming ? 4 : CGFloat(theme.miniRecorder.contentPaddingHorizontal)
    }
    
    // MARK: - Theme-Specific Backgrounds
    
    /// Basic theme: Clean, minimal, system-like
    private var basicBackground: some View {
        ZStack {
            theme.backgroundBase.opacity(0.95)
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .opacity(0.3)
        }
        .clipShape(Capsule())
    }
    
    /// Frosted Glass: Frosted glass with blur
    private var liquidGlassBackground: some View {
        ZStack {
            // Pure glass material
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
            
            // Subtle white overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(Capsule())
    }
    
    /// Cyberpunk: Dark with neon accents
    private var cyberpunkBackground: some View {
        ZStack {
            // Deep purple-black base
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.03, blue: 0.15),
                    Color(red: 0.03, green: 0.02, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Scanline effect
            VStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.02))
                        .frame(height: 1)
                    Spacer().frame(height: 2)
                }
            }
            .clipShape(Capsule())
        }
        .clipShape(Capsule())
    }
    
    /// Vintage: Warm paper texture
    private var vintageBackground: some View {
        ZStack {
            // Warm paper base
            Color(red: 0.94, green: 0.91, blue: 0.85)
            
            // Subtle aging gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color(red: 0.8, green: 0.7, blue: 0.5).opacity(0.1)
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: 100
            )
            
            // Paper grain texture simulation
            GeometryReader { geometry in
                Path { path in
                    let w = geometry.size.width
                    let h = geometry.size.height
                    var seed = 42
                    for _ in 0..<30 {
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
        .clipShape(Capsule())
    }
    
    /// Select background based on current theme
    @ViewBuilder
    private var backgroundView: some View {
        switch themeType {
        case .liquidGlass:
            liquidGlassBackground
        case .cyberpunk:
            cyberpunkBackground
        case .vintage:
            vintageBackground
        case .basic:
            basicBackground
        }
    }
    
    // MARK: - Theme-Specific Borders
    
    /// Basic: Simple subtle border
    private var basicBorder: some View {
        Capsule()
            .strokeBorder(theme.panelBorder.opacity(0.5), lineWidth: 0.5)
    }
    
    /// Frosted Glass: Fresnel-like highlight edge
    private var liquidGlassBorder: some View {
        ZStack {
            // Inner highlight (top-left)
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
            // Outer shadow edge (bottom-right)
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
    }
    
    /// Cyberpunk: Animated neon glow border
    private var cyberpunkBorder: some View {
        ZStack {
            // Main neon border (crisp)
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.85, blue: 0.9), // Cyan
                            Color(red: 0.8, green: 0.0, blue: 0.6), // Pink
                            Color(red: 0.5, green: 0.0, blue: 0.8)  // Purple
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
            
            // Inner glow effect (contained within capsule)
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.85, blue: 0.9).opacity(0.5),
                            Color(red: 0.8, green: 0.0, blue: 0.6).opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 4
                )
                .blur(radius: 3)
                .clipShape(Capsule().inset(by: -2)) // Contain blur within shape
            
            // Pulsing highlight
            Capsule()
                .strokeBorder(
                    Color(red: 0.0, green: 0.85, blue: 0.9).opacity(neonPulse ? 0.4 : 0.15),
                    lineWidth: 1
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                neonPulse = true
            }
        }
    }
    
    /// Vintage: Ink/Wax seal border
    private var vintageBorder: some View {
        ZStack {
            // Main rust-red border
            Capsule()
                .strokeBorder(
                    Color(red: 0.6, green: 0.25, blue: 0.15).opacity(0.6),
                    lineWidth: 1.5
                )
            
            // Inner light edge (paper lift effect)
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
                .padding(1)
        }
    }
    
    /// Select border based on current theme
    @ViewBuilder
    private var borderView: some View {
        switch themeType {
        case .liquidGlass:
            liquidGlassBorder
        case .cyberpunk:
            cyberpunkBorder
        case .vintage:
            vintageBorder
        case .basic:
            basicBorder
        }
    }
    
    // MARK: - Theme-Specific Shadows
    
    @ViewBuilder
    private var shadowLayer: some View {
        switch themeType {
        case .cyberpunk:
            // Neon underglow - contained within capsule bounds
            ZStack {
                // Cyan glow layer
                Capsule()
                    .fill(Color(red: 0.0, green: 0.85, blue: 0.9).opacity(0.3))
                    .blur(radius: 8)
                
                // Pink glow layer (offset down)
                Capsule()
                    .fill(Color(red: 0.8, green: 0.0, blue: 0.6).opacity(0.2))
                    .blur(radius: 12)
                    .offset(y: 4)
            }
            .clipShape(Capsule().inset(by: -15)) // Contain glow, allow slight bleed
        case .vintage:
            // Soft paper shadow
            Capsule()
                .fill(Color.clear)
                .shadow(color: Color(red: 0.3, green: 0.2, blue: 0.1).opacity(0.3), radius: 6, x: 0, y: 3)
        case .liquidGlass:
            // Subtle drop shadow
            Capsule()
                .fill(Color.clear)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        case .basic:
            // Basic: Clean shadow
            Capsule()
                .fill(Color.clear)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Standard Components
    
    private var statusView: some View {
        Group {
            if shouldShowLiveTranscriptStatus {
                RecorderLiveTranscriptView(whisperState: whisperState)
            } else {
                RecorderStatusDisplay(
                    currentState: whisperState.recordingState,
                    audioMeter: recorder.audioMeter,
                    recordingMode: whisperState.recordingMode
                )
            }
        }
    }
    
    private var contentLayout: some View {
        HStack(spacing: 0) {
            // Left button zone - always visible
            RecorderPromptButton(
                activePopover: $activePopover,
                buttonSize: sideButtonSize,
                padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            )
            .padding(.leading, sidePaddingHorizontal)

            Spacer()

            // Fixed visualizer zone
            statusView
                .frame(maxWidth: .infinity)

            Spacer()

            // Right button zone - always visible
            RecorderHistoryButton(
                activePopover: $activePopover,
                whisperState: whisperState,
                buttonSize: sideButtonSize,
                padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            )
            .padding(.trailing, sidePaddingHorizontal)
        }
        .padding(.vertical, 9)
    }

    private var recorderContentSize: CGSize {
        MiniRecorderPanel.contentSize(
            theme: theme,
            selectedModel: whisperState.currentTranscriptionModel
        )
    }
    
    private var recorderCapsule: some View {
        let width = recorderContentSize.width
        let height = recorderContentSize.height
        
        return ZStack {
            // Shadow layer (behind) - constrains the base shape but allows blur to bleed
            shadowLayer
                .frame(width: width, height: height)
            
            // Main capsule content
            contentLayout
                .frame(width: width, height: height)
                .background(backgroundView)
                .clipShape(Capsule())
                .overlay(borderView)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Center in the larger window
    }
    
    var body: some View {
        Group {
            if windowManager.isVisible {
                recorderCapsule
            }
        }
        .onChange(of: whisperState.currentTranscriptionModel?.name) { _, _ in
            windowManager.updateWindowMetricsIfNeeded()
        }
    }
}
