import SwiftUI

// Reusable background component
struct CardBackground: View {
    @Environment(\.theme) private var theme
    var isSelected: Bool
    var cornerRadius: CGFloat? = nil
    var useAccentGradientWhenSelected: Bool = false // This might need rethinking for pure glassmorphism
    
    var body: some View {
        let resolvedCornerRadius = cornerRadius ?? theme.cardCornerRadius
        RoundedRectangle(cornerRadius: resolvedCornerRadius)
            .fill(
                useAccentGradientWhenSelected && isSelected ? 
                    theme.cardGradientSelected :
                    theme.cardGradient
            )
            .overlay(
                RoundedRectangle(cornerRadius: resolvedCornerRadius)
                    .stroke(
                        isSelected ? theme.cardBorderSelected : theme.cardBorder,
                        lineWidth: 1.5 // Slightly thicker border for a defined glass edge
                    )
            )
            .shadow(
                color: isSelected ? theme.cardShadowSelected : theme.cardShadowDefault,
                radius: isSelected ? 15 : 10, // Larger radius for softer, more diffuse shadows
                x: 0,
                y: isSelected ? 8 : 5      // Slightly more y-offset for a lifted look
            )
    }
} 
