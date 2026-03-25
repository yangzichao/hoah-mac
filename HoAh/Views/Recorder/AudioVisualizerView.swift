import SwiftUI

struct AudioVisualizer: View {
    let audioMeter: AudioMeter
    let color: Color
    let isActive: Bool
    let spec: ThemeVisualizerSpec
    let showsFill: Bool
    
    // State to hold bar heights
    @State private var barHeights: [CGFloat] = []
    @State private var targetHeights: [CGFloat] = []
    
    // Sensitivity multipliers for each bar
    @State private var sensitivityMultipliers: [Double] = []
    @State private var initializedSpec: ThemeVisualizerSpec?
    
    // Animation phase for dynamic waveforms
    @State private var phase: Double = 0
    
    // Initialize with default empty state
    init(
        audioMeter: AudioMeter,
        color: Color,
        isActive: Bool,
        spec: ThemeVisualizerSpec,
        showsFill: Bool = true
    ) {
        self.audioMeter = audioMeter
        self.color = color
        self.isActive = isActive
        self.spec = spec
        self.showsFill = showsFill
    }
    
    var body: some View {
        Group {
            switch spec.style {
            case .bars:
                HStack(spacing: spec.barSpacing) {
                    ForEach(0..<min(barHeights.count, spec.barCount), id: \.self) { index in
                        RoundedRectangle(cornerRadius: spec.cornerRadius)
                            .fill(color)
                            .frame(width: spec.barWidth, height: barHeights[index])
                    }
                }
            case .waveform:
                // Connected waveform style
                WaveformShape(heights: barHeights, spacing: spec.barSpacing + spec.barWidth, phase: phase)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(height: spec.maxHeight)
                    .background {
                        if showsFill {
                            WaveformShape(heights: barHeights, spacing: spec.barSpacing + spec.barWidth, phase: phase)
                                .fill(LinearGradient(
                                    colors: [color.opacity(0.3), color.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                        }
                    }
            }
        }
        .onAppear {
            initializeBars()
        }
        .onChange(of: spec) { _, _ in
            initializeBars()
        }
        .onChange(of: audioMeter) { _, newValue in
            if isActive {
                updateBars(with: Float(newValue.averagePower))
            } else {
                resetBars()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if !newValue {
                resetBars()
            }
        }
    }
    
    private func initializeBars() {
        guard initializedSpec != spec || barHeights.count != spec.barCount else { return }

        var generator = SeededGenerator(seed: spec.sensitivitySeed)
        sensitivityMultipliers = (0..<spec.barCount).map { _ in
            Double.random(in: 0.2...1.9, using: &generator)
        }
        barHeights = Array(repeating: spec.minHeight, count: spec.barCount)
        targetHeights = Array(repeating: spec.minHeight, count: spec.barCount)
        initializedSpec = spec
        phase = 0
    }
    
    private func updateBars(with audioLevel: Float) {
        // Ensure initialized
        if barHeights.isEmpty { initializeBars() }
        
        // Increment phase to keep motion traveling through the visualizer.
        phase += spec.phaseStep
        
        let rawLevel = max(0, min(1, Double(audioLevel)))
        let hardThreshold: Double = 0.3
        let adjustedLevel = rawLevel < hardThreshold ? 0 : (rawLevel - hardThreshold) / (1.0 - hardThreshold)
        
        let range = spec.maxHeight - spec.minHeight
        let center = spec.barCount / 2
        
        for i in 0..<min(barHeights.count, spec.barCount) {
            let distanceFromCenter = abs(i - center)
            // For waveform, we might want less center-bias to make it look more like a scope
            let positionBias = spec.style == .waveform ? 0.2 : 0.4
            let positionMultiplier = 1.0 - (Double(distanceFromCenter) / Double(center)) * positionBias
            
            // Use randomized sensitivity
            let baseSensitivity = i < sensitivityMultipliers.count ? sensitivityMultipliers[i] : 1.0
            
            let finalSensitivity = baseSensitivity
            let baseLevel = adjustedLevel * positionMultiplier * finalSensitivity * spec.amplitudeBoost

            // Bars keep their original silhouette, but a stronger traveling crest now redistributes
            // energy across the row so the motion reads as left-to-right flow instead of simple jumps.
            let signedFlow = sin(Double(i) * spec.flowFrequency + phase)
            let crest = pow((signedFlow + 1.0) / 2.0, 1.35)
            let combinedLevel: Double
            if spec.style == .bars {
                let carriedEnergy = adjustedLevel * spec.flowIntensity * (0.3 + 0.7 * crest)
                let redistributedBase = baseLevel * (1.0 - spec.flowIntensity * 0.45 + spec.flowIntensity * signedFlow)
                combinedLevel = max(0, min(1.0, redistributedBase + carriedEnergy))
            } else {
                combinedLevel = min(1.0, baseLevel)
            }
            let targetHeight = spec.minHeight + CGFloat(combinedLevel) * range
            
            let isDecaying = targetHeight < targetHeights[i]
            let smoothingFactor: CGFloat = isDecaying ? 0.6 : 0.3
            
            targetHeights[i] = targetHeights[i] * (1 - smoothingFactor) + targetHeight * smoothingFactor
            
            // For waveform, we want smoother updates (less threshold)
            let updateThreshold = spec.style == .waveform ? 0.1 : 0.5
            
            if abs(barHeights[i] - targetHeights[i]) > updateThreshold {
                withAnimation(
                    isDecaying
                    ? .spring(response: 0.4, dampingFraction: 0.8)
                    : .spring(response: 0.3, dampingFraction: 0.7)
                ) {
                    barHeights[i] = targetHeights[i]
                }
            }
        }
    }
    
    private func resetBars() {
        withAnimation(.easeOut(duration: 0.15)) {
            barHeights = Array(repeating: spec.minHeight, count: spec.barCount)
            targetHeights = Array(repeating: spec.minHeight, count: spec.barCount)
        }
    }
}

// Custom shape for connecting the dots
struct WaveformShape: Shape {
    var heights: [CGFloat]
    let spacing: CGFloat
    var phase: Double // Add phase to control vertical oscillation direction
    
    // Animate the heights array changes
    var animatableData: [CGFloat] {
        get { heights }
        set { heights = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !heights.isEmpty else { return path }
        
        // Calculate total width of the waveform to center it
        let totalWidth = CGFloat(heights.count - 1) * spacing
        let startX = (rect.width - totalWidth) / 2
        let midY = rect.height / 2
        
        if heights.count < 2 { return path }
        
        // Helper to calculate Y position with oscillation
        func yPos(index: Int, height: CGFloat) -> CGFloat {
            // Create a carrier wave effect:
            // The height determines the AMPLITUDE (envelope).
            // The sin wave determines the instantanius VALUE (positive or negative).
            // We use (index + phase) to make it travel.
            // Using a lower frequency factor (e.g. 0.8) makes the waves visible.
            let signal = sin(Double(index) * 0.8 + phase)
            return midY - (height / 2) * CGFloat(signal) 
            // Note: height/2 is the max amplitude from center. 
            // When signal is 1, y is mid - amp (top). 
            // When signal is -1, y is mid + amp (bottom).
        }
        
        // Start point
        path.move(to: CGPoint(x: startX, y: yPos(index: 0, height: heights[0])))
        
        for i in 1..<heights.count {
            let x = startX + CGFloat(i) * spacing
            let y = yPos(index: i, height: heights[i])
            
            // Use cubic curves for smooth "cool" wave
            let prevX = startX + CGFloat(i-1) * spacing
            let prevY = yPos(index: i-1, height: heights[i-1])
            
            let ctrl1 = CGPoint(x: prevX + spacing / 2, y: prevY)
            let ctrl2 = CGPoint(x: x - spacing / 2, y: y)
            
            path.addCurve(to: CGPoint(x: x, y: y), control1: ctrl1, control2: ctrl2)
        }
        
        // Return path for stroke (it's open)
        // If we want fill, we need to close it. But stroke looks cooler for Cyberpunk.
        return path
    }
}

// Extension to make array animatable (VectorArithmetic) is complex.
// Simplified approach: Since we update `barHeights` via State, swiftui rebuilds the shape.
// However, `Shape` animation requires `animatableData`. Array<CGFloat> doesn't conform to VectorArithmetic.
// For now, we rely on the parent View's `barHeights` animation driven by `withAnimation` in `updateBars`.
// The `WaveformShape` will get re-rendered with interpolated values if we pass them correctly.
// ACTUALLY: The standard `withAnimation` on state updates the View body. The View passes the new array to the Shape.
// The Shape just draws the current frame. The smoothness comes from `barHeights` being interpolated?
// No, `barHeights` is [CGFloat]. `targetHeights` is the destination. `barHeights` is updated frame-by-frame?
// No, `withAnimation` interpolates basic types. Array is not interpolated by default.
// The *bar* visualization worked because `frame(height:)` is animatable.
// For the shape to animate smoothly, we actually need `AnimatablePair` recursion or just accept
// that `updateBars` is called frequently enough (it is, by audio callback) to look smooth.
// Given it's an audio visualizer, frame-by-frame updates are better than long animations.
// So we remove `animatableData` from the shape to avoid compiler errors.

struct StaticVisualizer: View {
    let color: Color
    let spec: ThemeVisualizerSpec
    let showsFill: Bool

    init(color: Color, spec: ThemeVisualizerSpec, showsFill: Bool = true) {
        self.color = color
        self.spec = spec
        self.showsFill = showsFill
    }
    
    var body: some View {
        Group {
            switch spec.style {
            case .bars:
                HStack(spacing: spec.barSpacing) {
                    ForEach(0..<spec.barCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: spec.cornerRadius)
                            .fill(color)
                            .frame(width: spec.barWidth, height: spec.minHeight)
                    }
                }
            case .waveform:
                // Flat line for static state
                Path { path in
                    let spacing = spec.barSpacing + spec.barWidth
                    let totalWidth = CGFloat(spec.barCount - 1) * spacing
                    // We don't have geometry here easily, but we know roughly the width
                    // Let's just draw a straight line
                    path.move(to: CGPoint(x: 0, y: spec.minHeight/2))
                    path.addLine(to: CGPoint(x: totalWidth, y: spec.minHeight/2))
                }
                .stroke(color.opacity(0.5), lineWidth: 1)
                .background {
                    if showsFill {
                        Path { path in
                            let spacing = spec.barSpacing + spec.barWidth
                            let totalWidth = CGFloat(spec.barCount - 1) * spacing
                            let midY = spec.minHeight / 2
                            path.move(to: CGPoint(x: 0, y: midY))
                            path.addLine(to: CGPoint(x: totalWidth, y: midY))
                        }
                        .stroke(color.opacity(0.15), lineWidth: 2)
                    }
                }
                .frame(width: CGFloat(spec.barCount) * (spec.barSpacing + spec.barWidth), height: spec.minHeight)
            }
        }
    }
}

// Simple Linear Congruential Generator for reproducible randomness
fileprivate struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
        // Scramble a bit initially to avoid similar seeds producing similar first results
        for _ in 0..<5 { _ = next() }
    }
    
    mutating func next() -> UInt64 {
        // Constants from MMIX by Donald Knuth
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}
