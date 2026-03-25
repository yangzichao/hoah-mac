import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.theme) private var theme
    @State private var textOpacity: CGFloat = 0
    @State private var showSecondaryElements = false
    @State private var showLanguageSelection = false
    @State private var showPermissions = false
    
    // Animation timing
    private let animationDelay = 0.2
    private let textAnimationDuration = 0.6
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack {
                    // Reusable background
                    OnboardingBackgroundView()
                    
                    // Content container
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Content Area
                            VStack(spacing: 60) {
                                Spacer()
                                    .frame(height: 40)
                                
                                // Title and subtitle
                                VStack(spacing: 16) {
                                    Text(LocalizedStringKey("Speech to Text, Made Simple"))
                                        .font(.system(size: min(geometry.size.width * 0.055, 42), weight: .bold, design: .rounded))
                                        .foregroundColor(theme.textPrimary)
                                        .opacity(textOpacity)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Text(LocalizedStringKey("HoAh is the cleanest, not-for-profit speech-to-text tool."))
                                        .font(.system(size: min(geometry.size.width * 0.032, 24), weight: .medium, design: .rounded))
                                        .foregroundColor(theme.textSecondary)
                                        .opacity(textOpacity)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)

                                    Text(LocalizedStringKey("Multilingual support · Fun AI transcription enhancements · Bring Your Own Key (BYOK)"))
                                        .font(.system(size: min(geometry.size.width * 0.026, 18), weight: .regular, design: .rounded))
                                        .foregroundColor(theme.textSecondary.opacity(0.85))
                                        .opacity(textOpacity)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                // Typewriter roles animation removed
                            }
                            .padding(.top, geometry.size.height * 0.15)
                            
                            Spacer(minLength: geometry.size.height * 0.2)
                            
                            // Bottom navigation
                            if showSecondaryElements {
                                VStack(spacing: 20) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                            showLanguageSelection = true
                                        }
                                    }) {
                                        Text("Get Started")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(theme.primaryButtonText)
                                            .frame(width: min(geometry.size.width * 0.3, 200), height: 50)
                                            .background(theme.buttonGradient)
                                            .cornerRadius(25)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    
                                    
                                }
                                .padding(.bottom, 35)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
            
            if showLanguageSelection {
                OnboardingLanguageSelectionView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showLanguageSelection = false
                        showPermissions = true
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            if showPermissions {
                OnboardingPermissionsView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Text fade in
        withAnimation(.easeOut(duration: textAnimationDuration).delay(animationDelay)) {
            textOpacity = 1
        }
        
        // Show secondary elements
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay * 3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showSecondaryElements = true
            }
        }
    }
}

// MARK: - Supporting Views
struct OnboardingBackgroundView: View {
    @Environment(\.theme) private var theme
    @State private var glowOpacity: CGFloat = 0
    @State private var glowScale: CGFloat = 0.8
    @State private var particlesActive = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // For Frosted Glass (transparent base), add a strong blur material AND a solid backing to obscure underlying content
                if theme.backgroundBase == .clear {
                    // 1. Solid backing to prevent "see-through" mess of stacked views
                    Color(NSColor.windowBackgroundColor).opacity(0.95)
                        .ignoresSafeArea()
                    
                    // 2. Material for the glassy texture
                    Rectangle()
                        .fill(.regularMaterial)
                        .ignoresSafeArea()
                }

                // Base background with black gradient
                theme.backgroundBase
                    .overlay(
                        LinearGradient(
                            colors: [
                                theme.backgroundGradientTop,
                                theme.backgroundGradientMid,
                                theme.backgroundGradientBottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Animated glow effect
                Circle()
                    .fill(theme.glowColor)
                    .frame(width: min(geometry.size.width, geometry.size.height) * 0.4)
                    .blur(radius: 100)
                    .opacity(glowOpacity)
                    .scaleEffect(glowScale)
                    .position(
                        x: geometry.size.width * 0.5,
                        y: geometry.size.height * 0.3
                    )
                
                // Enhanced particles with reduced opacity
                ParticlesView(isActive: $particlesActive)
                    .opacity(theme.particleOpacity)
                    .drawingGroup()
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Glow animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowOpacity = 0.3
            glowScale = 1.2
        }
        
        // Start particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            particlesActive = true
        }
    }
}

// MARK: - Particles
struct ParticlesView: View {
    @Binding var isActive: Bool
    let particleCount = 60 // Increased particle count
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let timeOffset = timeline.date.timeIntervalSinceReferenceDate
                
                for i in 0..<particleCount {
                    let position = particlePosition(index: i, time: timeOffset, size: size)
                    let opacity = particleOpacity(index: i, time: timeOffset)
                    let scale = particleScale(index: i, time: timeOffset)
                    
                    context.opacity = opacity
                    context.fill(
                        Circle().path(in: CGRect(
                            x: position.x - scale/2,
                            y: position.y - scale/2,
                            width: scale,
                            height: scale
                        )),
                        with: .color(.white)
                    )
                }
            }
        }
        .opacity(isActive ? 1 : 0)
    }
    
    private func particlePosition(index: Int, time: TimeInterval, size: CGSize) -> CGPoint {
        let relativeIndex = Double(index) / Double(particleCount)
        let speed = 0.3 // Slower, more graceful movement
        let radius = min(size.width, size.height) * 0.45
        
        let angle = time * speed + relativeIndex * .pi * 4
        let x = sin(angle) * radius + size.width * 0.5
        let y = cos(angle * 0.5) * radius + size.height * 0.5
        
        return CGPoint(x: x, y: y)
    }
    
    private func particleOpacity(index: Int, time: TimeInterval) -> Double {
        let relativeIndex = Double(index) / Double(particleCount)
        return (sin(time + relativeIndex * .pi * 2) + 1) * 0.3 // Reduced opacity for subtlety
    }
    
    private func particleScale(index: Int, time: TimeInterval) -> CGFloat {
        let relativeIndex = Double(index) / Double(particleCount)
        let baseScale: CGFloat = 3
        return baseScale + sin(time * 2 + relativeIndex * .pi) * 2
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
} 
