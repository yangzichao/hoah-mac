import SwiftUI

enum UITheme: String, CaseIterable {
    case basic = "basic"
    case liquidGlass = "liquidGlass"
    case cyberpunk = "cyberpunk"
    case vintage = "vintage"
    
    var displayNameKey: LocalizedStringKey {
        switch self {
        case .basic:
            return LocalizedStringKey("ui_theme_basic")
        case .liquidGlass:
            return LocalizedStringKey("ui_theme_liquid_glass")
        case .cyberpunk:
            return LocalizedStringKey("ui_theme_cyberpunk")
        case .vintage:
            return LocalizedStringKey("ui_theme_vintage")
        }
    }
}

struct ThemePalette {
    let id: UITheme
    let typography: ThemeTypography
    let accentColor: Color
    let buttonGradient: LinearGradient
    let primaryButtonBackground: Color
    let primaryButtonText: Color
    let windowBackground: Color
    let controlBackground: Color
    let separatorColor: Color
    let shadowColor: Color
    let backgroundBase: Color
    let backgroundGradientTop: Color
    let backgroundGradientMid: Color
    let backgroundGradientBottom: Color
    let glowColor: Color
    let particleOpacity: Double
    let pageIndicatorActive: Color
    let pageIndicatorInactive: Color
    let cardGradient: LinearGradient
    let cardGradientSelected: LinearGradient
    let cardBorder: LinearGradient
    let cardBorderSelected: LinearGradient
    let cardShadowDefault: Color
    let cardShadowSelected: Color
    let cardCornerRadius: CGFloat
    let keyCardBackground: Color
    let keyCardBorder: Color
    let keyCardShadow: Color
    let panelBackground: Color
    let panelBorder: Color
    let panelButtonBackground: Color
    let inputBackground: Color
    let inputBorder: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let statusSuccess: Color
    let statusPending: Color
    let statusWarning: Color
    let statusError: Color
    let statusInfo: Color
    let windowCornerRadius: CGFloat
    let windowInset: CGFloat
    let windowFrameBackground: Color
    let windowBorderColor: Color
    let windowBorderWidth: CGFloat
    let windowControlsBackground: Color
    let windowControlsBorder: Color
    let windowControlsShadow: Color
    let trafficLightClose: Color
    let trafficLightMinimize: Color
    let trafficLightZoom: Color
    let windowHeaderBackground: Color
    let windowHeaderBorder: Color
    let notificationBackground: Color
    let notificationSecondaryBackground: Color
    let notificationBorder: Color
    let notificationTitle: Color
    let notificationBody: Color
    let notificationActionBackground: Color
    let notificationActionText: Color
    let notificationAccent: Color
    let sidebarBackground: Color
    let sidebarItemBackground: Color
    let sidebarItemBackgroundSelected: Color
    let sidebarItemText: Color
    let sidebarItemTextSelected: Color
    let sidebarItemIcon: Color
    let sidebarItemIconSelected: Color
    
    // Component Specs
    let visualizer: ThemeVisualizerSpec
    let miniRecorder: ThemeMiniRecorderSpec
}

enum ThemeFontWeight: String, Codable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black

    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        }
    }
}

enum ThemeFontDesign: String, Codable {
    case `default`
    case serif
    case rounded
    case monospaced

    var fontDesign: Font.Design {
        switch self {
        case .default:
            return .default
        case .serif:
            return .serif
        case .rounded:
            return .rounded
        case .monospaced:
            return .monospaced
        }
    }
}

struct ThemeFontSpec: Codable, Hashable {
    let size: Double
    let weight: ThemeFontWeight
    let design: ThemeFontDesign

    init(size: Double, weight: ThemeFontWeight, design: ThemeFontDesign = .default) {
        self.size = size
        self.weight = weight
        self.design = design
    }

    var font: Font {
        Font.system(size: CGFloat(size), weight: weight.fontWeight, design: design.fontDesign)
    }
}

struct ThemeTypographySignature: Codable, Hashable {
    let title: ThemeFontSpec
    let title2: ThemeFontSpec
    let title3: ThemeFontSpec
    let headline: ThemeFontSpec
    let subheadline: ThemeFontSpec
    let body: ThemeFontSpec
    let caption: ThemeFontSpec
    let caption2: ThemeFontSpec
    let sidebarTitle: ThemeFontSpec
    let sidebarItem: ThemeFontSpec
}

struct ThemeTypography {
    let title: Font
    let title2: Font
    let title3: Font
    let headline: Font
    let subheadline: Font
    let body: Font
    let caption: Font
    let caption2: Font
    let sidebarTitle: Font
    let sidebarItem: Font
    let signature: ThemeTypographySignature

    init(
        title: ThemeFontSpec,
        title2: ThemeFontSpec,
        title3: ThemeFontSpec,
        headline: ThemeFontSpec,
        subheadline: ThemeFontSpec,
        body: ThemeFontSpec,
        caption: ThemeFontSpec,
        caption2: ThemeFontSpec,
        sidebarTitle: ThemeFontSpec,
        sidebarItem: ThemeFontSpec
    ) {
        self.title = title.font
        self.title2 = title2.font
        self.title3 = title3.font
        self.headline = headline.font
        self.subheadline = subheadline.font
        self.body = body.font
        self.caption = caption.font
        self.caption2 = caption2.font
        self.sidebarTitle = sidebarTitle.font
        self.sidebarItem = sidebarItem.font
        self.signature = ThemeTypographySignature(
            title: title,
            title2: title2,
            title3: title3,
            headline: headline,
            subheadline: subheadline,
            body: body,
            caption: caption,
            caption2: caption2,
            sidebarTitle: sidebarTitle,
            sidebarItem: sidebarItem
        )
    }
}

extension ThemePalette {
    private static let systemAccent = Color(NSColor.controlAccentColor)

    static let basic = ThemePalette(
        id: .basic,
        typography: ThemeTypography(
            title: .init(size: 24, weight: .bold),
            title2: .init(size: 20, weight: .semibold),
            title3: .init(size: 18, weight: .semibold),
            headline: .init(size: 15, weight: .semibold),
            subheadline: .init(size: 13, weight: .regular),
            body: .init(size: 14, weight: .regular),
            caption: .init(size: 12, weight: .regular),
            caption2: .init(size: 11, weight: .regular),
            sidebarTitle: .init(size: 14, weight: .bold),
            sidebarItem: .init(size: 14, weight: .medium)
        ),
        accentColor: ThemePalette.systemAccent,
        buttonGradient: LinearGradient(
            colors: [ThemePalette.systemAccent, ThemePalette.systemAccent.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        ),
        primaryButtonBackground: Color(NSColor.controlColor), // Retained from original
        primaryButtonText: .white,
        windowBackground: Color(NSColor.windowBackgroundColor), // Light gray usually
        controlBackground: Color(NSColor.controlBackgroundColor),
        separatorColor: Color(NSColor.separatorColor), // Retained from original
        shadowColor: Color.black.opacity(0.1),
        backgroundBase: Color(NSColor.windowBackgroundColor), // Retained from original
        backgroundGradientTop: Color(NSColor.windowBackgroundColor),
        backgroundGradientMid: Color(NSColor.windowBackgroundColor),
        backgroundGradientBottom: Color(NSColor.windowBackgroundColor),
        glowColor: ThemePalette.systemAccent,
        particleOpacity: 0.0,
        pageIndicatorActive: ThemePalette.systemAccent,
        pageIndicatorInactive: Color(NSColor.tertiaryLabelColor),
        
        // Cards - Crisp and distinct
        cardGradient: LinearGradient(
            gradient: Gradient(colors: [
                Color(NSColor.controlBackgroundColor), // White
                Color(NSColor.controlBackgroundColor)
            ]),
            startPoint: .top,
            endPoint: .bottom
        ),
        cardGradientSelected: LinearGradient(
            gradient: Gradient(colors: [
                ThemePalette.systemAccent.opacity(0.1),
                ThemePalette.systemAccent.opacity(0.05)
            ]),
            startPoint: .top,
            endPoint: .bottom
        ),
        cardBorder: LinearGradient(
            gradient: Gradient(colors: [Color(NSColor.separatorColor).opacity(0.5)]),
            startPoint: .top,
            endPoint: .bottom
        ),
        cardBorderSelected: LinearGradient(
            gradient: Gradient(colors: [ThemePalette.systemAccent.opacity(0.5)]),
            startPoint: .top,
            endPoint: .bottom
        ),
        cardShadowDefault: Color.black.opacity(0.05), // Subtle depth
        cardShadowSelected: ThemePalette.systemAccent.opacity(0.15),
        cardCornerRadius: 10,
        
        keyCardBackground: ThemePalette.systemAccent,
        keyCardBorder: Color.white.opacity(0.2),
        keyCardShadow: ThemePalette.systemAccent.opacity(0.3),
        
        // Panels
        panelBackground: Color(NSColor.controlBackgroundColor),
        panelBorder: Color(NSColor.separatorColor),
        panelButtonBackground: Color(NSColor.controlBackgroundColor),
        
        inputBackground: Color(NSColor.textBackgroundColor), // Pure white in light mode
        inputBorder: Color(NSColor.separatorColor),
        
        textPrimary: Color(NSColor.labelColor),
        textSecondary: Color(NSColor.secondaryLabelColor),
        textMuted: Color(NSColor.tertiaryLabelColor), // Retained from original
        
        statusSuccess: Color(NSColor.systemGreen),
        statusPending: .yellow, // Retained from original
        statusWarning: Color(NSColor.systemOrange),
        statusError: Color(NSColor.systemRed),
        statusInfo: .blue, // Retained from original
        windowCornerRadius: 22, // Retained from original
        windowInset: 10, // Retained from original
        
        // Window Chrome
        windowFrameBackground: Color(NSColor.windowBackgroundColor),
        windowBorderColor: Color(NSColor.separatorColor),
        windowBorderWidth: 0.5,
        windowControlsBackground: .clear,
        windowControlsBorder: .clear,
        windowControlsShadow: .clear,
        trafficLightClose: Color(NSColor.systemRed),
        trafficLightMinimize: Color(NSColor.systemYellow),
        trafficLightZoom: Color(NSColor.systemGreen),
        windowHeaderBackground: .clear,
        windowHeaderBorder: .clear,
        notificationBackground: Color(NSColor.controlBackgroundColor).opacity(0.98),
        notificationSecondaryBackground: Color(NSColor.windowBackgroundColor),
        notificationBorder: Color(NSColor.separatorColor),
        notificationTitle: Color(NSColor.labelColor),
        notificationBody: Color(NSColor.secondaryLabelColor),
        notificationActionBackground: ThemePalette.systemAccent,
        notificationActionText: .white,
        notificationAccent: ThemePalette.systemAccent,
        
        // Sidebar - Slightly distinct from main content
        sidebarBackground: Color(NSColor.alternatingContentBackgroundColors[1]),
        sidebarItemBackground: Color.clear,
        sidebarItemBackgroundSelected: ThemePalette.systemAccent.opacity(0.18), // Native-like selection
        sidebarItemText: Color(NSColor.labelColor),
        sidebarItemTextSelected: .white, // White text for contrast on blue selection
        sidebarItemIcon: Color(NSColor.secondaryLabelColor),
        sidebarItemIconSelected: .white, // White icon for contrast on blue selection
        
        visualizer: .standard,
        miniRecorder: .standard
    )
    
    // Frosted Glass Theme - True Transparency
    static let liquidGlass = ThemePalette(
        id: .liquidGlass,
        typography: ThemeTypography(
            title: .init(size: 24, weight: .bold),
            title2: .init(size: 20, weight: .semibold),
            title3: .init(size: 18, weight: .semibold),
            headline: .init(size: 14, weight: .semibold),
            subheadline: .init(size: 13, weight: .regular),
            body: .init(size: 14, weight: .regular),
            caption: .init(size: 12, weight: .regular),
            caption2: .init(size: 11, weight: .regular),
            sidebarTitle: .init(size: 14, weight: .semibold),
            sidebarItem: .init(size: 14, weight: .medium)
        ),
        accentColor: ThemePalette.systemAccent,
        buttonGradient: LinearGradient(
            colors: [ThemePalette.systemAccent.opacity(0.9), ThemePalette.systemAccent.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        ),
        primaryButtonBackground: Color(NSColor.controlColor).opacity(0.3), // Translucent button
        primaryButtonText: .white,
        
        // Window Background: CLEAR to allow the ContentView Material to show through
        windowBackground: .clear,
        controlBackground: .clear,
        separatorColor: Color(NSColor.separatorColor).opacity(0.3),
        shadowColor: Color.black.opacity(0.15),
        
        backgroundBase: .clear,
        backgroundGradientTop: .clear,
        backgroundGradientMid: .clear,
        backgroundGradientBottom: .clear,
        
        glowColor: ThemePalette.systemAccent,
        particleOpacity: 0.3,
        
        pageIndicatorActive: ThemePalette.systemAccent,
        pageIndicatorInactive: Color(NSColor.tertiaryLabelColor),
        
        // Glass Cards (The Bento Boxes)
        cardGradient: LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(NSColor.controlBackgroundColor).opacity(0.2), location: 0.0),
                .init(color: Color(NSColor.controlBackgroundColor).opacity(0.05), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardGradientSelected: LinearGradient(
            gradient: Gradient(stops: [
                .init(color: ThemePalette.systemAccent.opacity(0.2), location: 0.0),
                .init(color: ThemePalette.systemAccent.opacity(0.05), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        
        // Glass Edge Highlight (Fresnel Effect)
        cardBorder: LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(0.4), location: 0.0), // Strong top-left highlight
                .init(color: Color.black.opacity(0.1), location: 1.0)  // Soft bottom-right shadow
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardBorderSelected: LinearGradient(
            gradient: Gradient(colors: [
                ThemePalette.systemAccent.opacity(0.7),
                ThemePalette.systemAccent.opacity(0.3)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        
        cardShadowDefault: Color.black.opacity(0.1),
        cardShadowSelected: ThemePalette.systemAccent.opacity(0.3),
        cardCornerRadius: 24, // "Pill-like" roundness
        
        keyCardBackground: ThemePalette.systemAccent.opacity(0.8),
        keyCardBorder: Color.white.opacity(0.4),
        keyCardShadow: ThemePalette.systemAccent.opacity(0.5),
        
        // Panels
        panelBackground: Color(NSColor.controlBackgroundColor).opacity(0.1), // Very subtle fill
        panelBorder: Color.white.opacity(0.15),
        panelButtonBackground: Color(NSColor.controlBackgroundColor).opacity(0.15),
        
        inputBackground: Color(NSColor.textBackgroundColor).opacity(0.15),
        inputBorder: Color.white.opacity(0.1),
        
        textPrimary: Color(NSColor.labelColor),
        textSecondary: Color(NSColor.secondaryLabelColor),
        textMuted: Color(NSColor.tertiaryLabelColor),
        
        statusSuccess: Color(red: 0.0, green: 0.6, blue: 0.3), // Darker green for glass contrast
        statusPending: .yellow,
        statusWarning: .orange,
        statusError: Color(red: 0.8, green: 0.2, blue: 0.2), // Slightly deeper red
        statusInfo: .blue,
        windowCornerRadius: 28,
        windowInset: 12,
        windowFrameBackground: Color(NSColor.windowBackgroundColor).opacity(0.9),
        windowBorderColor: Color(NSColor.separatorColor).opacity(0.35),
        windowBorderWidth: 1,
        windowControlsBackground: Color.white.opacity(0.16),
        windowControlsBorder: Color.white.opacity(0.25),
        windowControlsShadow: Color.black.opacity(0.2),
        trafficLightClose: Color(red: 1.0, green: 0.35, blue: 0.35),
        trafficLightMinimize: Color(red: 1.0, green: 0.78, blue: 0.25),
        trafficLightZoom: Color(red: 0.35, green: 0.85, blue: 0.55),
        windowHeaderBackground: Color.white.opacity(0.18),
        windowHeaderBorder: Color.white.opacity(0.25),
        notificationBackground: Color(NSColor.windowBackgroundColor).opacity(0.7),
        notificationSecondaryBackground: Color(NSColor.windowBackgroundColor).opacity(0.5),
        notificationBorder: Color.white.opacity(0.2),
        notificationTitle: .white,
        notificationBody: Color.white.opacity(0.9),
        notificationActionBackground: ThemePalette.systemAccent,
        notificationActionText: .white,
        notificationAccent: ThemePalette.systemAccent,
        
        // Sidebar - Truly Transparent
        sidebarBackground: .clear,
        sidebarItemBackground: .clear,
        sidebarItemBackgroundSelected: Color.white.opacity(0.2), // Frosted glass selection
        sidebarItemText: Color.black.opacity(0.8), // High contrast on glass
        sidebarItemTextSelected: Color.black,
        sidebarItemIcon: Color.black.opacity(0.6),
        sidebarItemIconSelected: ThemePalette.systemAccent, // Accent color for icon
        
        // Sleek, modern glass look with subtle flow
        visualizer: ThemeVisualizerSpec(
            style: .bars,
            barCount: 14,
            barWidth: 3.0,
            barSpacing: 2.0,
            minHeight: 4.0,
            maxHeight: 28.0,
            cornerRadius: 1.5,
            sensitivitySeed: 101, // Glassy seed
            amplitudeBoost: 1.2,
            flowIntensity: 0.28,
            flowFrequency: 0.75,
            phaseStep: 0.14
        ),
        miniRecorder: .standard
    )
    
    // MARK: - Cyberpunk Theme
    static let cyberpunk = ThemePalette(
        id: .cyberpunk,
        typography: ThemeTypography(
            title: .init(size: 24, weight: .bold, design: .monospaced),
            title2: .init(size: 20, weight: .semibold, design: .monospaced),
            title3: .init(size: 18, weight: .semibold, design: .monospaced),
            headline: .init(size: 14, weight: .semibold, design: .monospaced),
            subheadline: .init(size: 13, weight: .regular, design: .monospaced),
            body: .init(size: 14, weight: .regular, design: .monospaced),
            caption: .init(size: 12, weight: .regular, design: .monospaced),
            caption2: .init(size: 11, weight: .regular, design: .monospaced),
            sidebarTitle: .init(size: 14, weight: .semibold, design: .monospaced),
            sidebarItem: .init(size: 14, weight: .medium, design: .monospaced)
        ),
        accentColor: Color(red: 0.0, green: 0.85, blue: 0.9), // Softer Neon Cyan
        buttonGradient: LinearGradient(
            colors: [Color(red: 0.8, green: 0.0, blue: 0.6), Color(red: 0.5, green: 0.0, blue: 0.8)], // Pink to Purple
            startPoint: .leading,
            endPoint: .trailing
        ),
        primaryButtonBackground: Color(red: 0.1, green: 0.1, blue: 0.2),
        primaryButtonText: Color.white, // White text for better contrast on dark/gradient background
        
        windowBackground: Color(red: 0.05, green: 0.03, blue: 0.1), // Purple-tinted black
        controlBackground: Color(red: 0.08, green: 0.05, blue: 0.15),
        separatorColor: Color(red: 0.8, green: 0.0, blue: 1.0).opacity(0.3), // Purple lines
        shadowColor: Color(red: 0.6, green: 0.0, blue: 1.0).opacity(0.4), // Purple glow shadow
        
        backgroundBase: Color(red: 0.03, green: 0.02, blue: 0.08),
        backgroundGradientTop: Color(red: 0.05, green: 0.0, blue: 0.15), // Deep purple
        backgroundGradientMid: Color(red: 0.15, green: 0.0, blue: 0.25), // Rich violet
        backgroundGradientBottom: Color(red: 0.02, green: 0.02, blue: 0.05),
        
        glowColor: Color(red: 0.8, green: 0.0, blue: 1.0), // Purple glow
        particleOpacity: 0.8, // Visible digital noise
        
        pageIndicatorActive: Color(red: 1.0, green: 0.0, blue: 0.8), // Hot pink
        pageIndicatorInactive: Color(red: 0.3, green: 0.1, blue: 0.4),
        
        // Tech Cards with purple accent
        cardGradient: LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.08, green: 0.03, blue: 0.15).opacity(0.9),
                Color(red: 0.03, green: 0.02, blue: 0.08).opacity(0.95)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardGradientSelected: LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.15, green: 0.05, blue: 0.25),
                Color(red: 0.08, green: 0.02, blue: 0.15)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        
        // Neon Borders - More Purple!
        cardBorder: LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.8), // Neon Cyan (High Opacity)
                Color(red: 1.0, green: 0.0, blue: 0.8).opacity(0.8)  // Neon Pink (High Opacity)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardBorderSelected: LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 1.0, green: 0.0, blue: 0.8), // Hot Pink
                Color(red: 0.6, green: 0.0, blue: 1.0), // Purple
                Color(red: 0.0, green: 0.8, blue: 1.0)  // Cyan
            ]),
            startPoint: .leading,
            endPoint: .trailing
        ),
        
        cardShadowDefault: Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.4), // Cyan glow (stronger)
        cardShadowSelected: Color(red: 1.0, green: 0.0, blue: 0.8).opacity(0.7), // Intense Pink glow
        cardCornerRadius: 2, // Sharp tech corners
        
        keyCardBackground: Color(red: 0.1, green: 0.1, blue: 0.1),
        keyCardBorder: Color(red: 0.0, green: 1.0, blue: 0.0),
        keyCardShadow: Color(red: 0.0, green: 1.0, blue: 0.0).opacity(0.5),
        
        panelBackground: Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.8), // Slightly lighter
        panelBorder: Color(red: 0.2, green: 0.2, blue: 0.3),
        panelButtonBackground: Color(red: 0.15, green: 0.15, blue: 0.2),
        
        inputBackground: Color(red: 0.15, green: 0.15, blue: 0.2), // Dark Charcoal
        inputBorder: Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.3),
        
        textPrimary: Color.white,
        textSecondary: Color(red: 0.8, green: 0.85, blue: 0.9), // Light Grey-Blue
        textMuted: Color(red: 0.6, green: 0.65, blue: 0.7), // Readable Grey
        
        statusSuccess: Color(red: 0.0, green: 0.8, blue: 0.5), // Softer Teal-Green
        statusPending: Color(red: 1.0, green: 1.0, blue: 0.0),
        statusWarning: Color(red: 1.0, green: 0.5, blue: 0.0),
        statusError: Color(red: 1.0, green: 0.0, blue: 0.0),
        statusInfo: Color(red: 0.0, green: 0.8, blue: 1.0),
        windowCornerRadius: 24,
        windowInset: 12,
        windowFrameBackground: Color(red: 0.04, green: 0.04, blue: 0.07),
        windowBorderColor: Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.3),
        windowBorderWidth: 1,
        windowControlsBackground: Color(red: 0.08, green: 0.08, blue: 0.14),
        windowControlsBorder: Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.25),
        windowControlsShadow: Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.15),
        trafficLightClose: Color(red: 1.0, green: 0.2, blue: 0.6),
        trafficLightMinimize: Color(red: 1.0, green: 0.85, blue: 0.0),
        trafficLightZoom: Color(red: 0.0, green: 1.0, blue: 0.8),
        windowHeaderBackground: Color(red: 0.05, green: 0.05, blue: 0.1),
        windowHeaderBorder: Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.2),
        notificationBackground: Color(red: 0.02, green: 0.02, blue: 0.1),
        notificationSecondaryBackground: Color(red: 0.05, green: 0.03, blue: 0.15),
        notificationBorder: Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.3),
        notificationTitle: .white,
        notificationBody: Color(red: 0.4, green: 0.8, blue: 1.0),
        notificationActionBackground: Color(red: 0.0, green: 1.0, blue: 1.0),
        notificationActionText: .black,
        notificationAccent: Color(red: 0.0, green: 1.0, blue: 1.0),
        sidebarBackground: Color(red: 0.07, green: 0.07, blue: 0.11),
        sidebarItemBackground: Color.clear,
        sidebarItemBackgroundSelected: Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.2),
        sidebarItemText: Color.white,
        sidebarItemTextSelected: Color.white,
        sidebarItemIcon: Color.white.opacity(0.8),
        sidebarItemIconSelected: Color.white,
        
        // Tech/Waveform look: High resolution connected graph
        visualizer: ThemeVisualizerSpec(
            style: .waveform,
            barCount: 32, // High res for smoother wave
            barWidth: 2.0, // Used for point spacing calculation in waveform
            barSpacing: 1.0,
            minHeight: 2.0,
            maxHeight: 34.0,
            cornerRadius: 0.0,
            sensitivitySeed: 2077, // Cyberpunk seed
            amplitudeBoost: 1.5, // Cyberpunk high energy
            flowIntensity: 0.0,
            flowFrequency: 0.8,
            phaseStep: 0.15
        ),
        // Slightly wider to accommodate more bars if needed, but 184 fits 16 bars of width 3+1.5=72px easily.
        // Let's make it slightly wider just to look more "HUD" like.
        miniRecorder: ThemeMiniRecorderSpec(
            width: 200, // Wider for the waveform
            height: 40,
            contentPaddingHorizontal: 8
        )
    )
    
    // MARK: - Vintage/Paper Theme
    static let vintage = ThemePalette(
        id: .vintage,
        typography: ThemeTypography(
            title: .init(size: 28, weight: .bold, design: .serif),
            title2: .init(size: 22, weight: .semibold, design: .serif),
            title3: .init(size: 19, weight: .semibold, design: .serif),
            headline: .init(size: 15, weight: .semibold, design: .serif),
            subheadline: .init(size: 14, weight: .regular, design: .serif),
            body: .init(size: 15, weight: .regular, design: .serif),
            caption: .init(size: 13, weight: .regular, design: .serif),
            caption2: .init(size: 12, weight: .regular, design: .serif),
            sidebarTitle: .init(size: 15, weight: .semibold, design: .serif),
            sidebarItem: .init(size: 15, weight: .medium, design: .serif)
        ),
        accentColor: Color(red: 0.6, green: 0.2, blue: 0.1), // Rust Red
        buttonGradient: LinearGradient(
            colors: [Color(red: 0.5, green: 0.25, blue: 0.15), Color(red: 0.4, green: 0.2, blue: 0.1)],
            startPoint: .top,
            endPoint: .bottom
        ),
        primaryButtonBackground: Color(red: 0.93, green: 0.90, blue: 0.85),
        primaryButtonText: Color(red: 0.98, green: 0.95, blue: 0.90),
        
        windowBackground: Color(red: 0.96, green: 0.94, blue: 0.88), // Warm paper
        controlBackground: Color(red: 0.92, green: 0.89, blue: 0.82),
        separatorColor: Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.3),
        shadowColor: Color(red: 0.3, green: 0.2, blue: 0.1).opacity(0.2),
        
        backgroundBase: Color(red: 0.96, green: 0.94, blue: 0.88),
        backgroundGradientTop: Color(red: 0.96, green: 0.94, blue: 0.88),
        backgroundGradientMid: Color(red: 0.94, green: 0.91, blue: 0.84),
        backgroundGradientBottom: Color(red: 0.92, green: 0.89, blue: 0.80),
        
        glowColor: Color(red: 0.8, green: 0.6, blue: 0.4),
        particleOpacity: 0.0,
        
        pageIndicatorActive: Color(red: 0.6, green: 0.2, blue: 0.1),
        pageIndicatorInactive: Color(red: 0.7, green: 0.6, blue: 0.5),
        
        // Paper Cards
        cardGradient: LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.99, green: 0.98, blue: 0.96),
                Color(red: 0.95, green: 0.93, blue: 0.89)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardGradientSelected: LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.95, green: 0.93, blue: 0.89),
                Color(red: 0.90, green: 0.85, blue: 0.78)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        
        // Ink/Pencil Borders
        cardBorder: LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.5, green: 0.4, blue: 0.3).opacity(0.3),
                Color(red: 0.5, green: 0.4, blue: 0.3).opacity(0.2)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardBorderSelected: LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.6, green: 0.2, blue: 0.1), // Rust border
                Color(red: 0.6, green: 0.2, blue: 0.1).opacity(0.6)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        
        cardShadowDefault: Color(red: 0.3, green: 0.2, blue: 0.1).opacity(0.1),
        cardShadowSelected: Color(red: 0.3, green: 0.2, blue: 0.1).opacity(0.2),
        cardCornerRadius: 4, // Slight rounding
        
        keyCardBackground: Color(red: 0.9, green: 0.85, blue: 0.75),
        keyCardBorder: Color(red: 0.4, green: 0.3, blue: 0.2),
        keyCardShadow: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.3),
        
        panelBackground: Color(red: 0.93, green: 0.90, blue: 0.85).opacity(0.6),
        panelBorder: Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.2),
        panelButtonBackground: Color(red: 0.9, green: 0.87, blue: 0.8),
        
        inputBackground: Color(red: 1.0, green: 0.98, blue: 0.95), // Off-white
        inputBorder: Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.4),
        
        // Ink Text
        textPrimary: Color(red: 0.2, green: 0.15, blue: 0.1), // Sepia Black
        textSecondary: Color(red: 0.4, green: 0.35, blue: 0.3),
        textMuted: Color(red: 0.6, green: 0.55, blue: 0.5),
        
        statusSuccess: Color(red: 0.1, green: 0.4, blue: 0.15), // Darker forest green
        statusPending: Color(red: 0.7, green: 0.6, blue: 0.2),
        statusWarning: Color(red: 0.8, green: 0.4, blue: 0.1),
        statusError: Color(red: 0.7, green: 0.2, blue: 0.2),
        statusInfo: Color(red: 0.2, green: 0.4, blue: 0.6),
        windowCornerRadius: 20,
        windowInset: 10,
        windowFrameBackground: Color(red: 0.96, green: 0.94, blue: 0.88),
        windowBorderColor: Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.3),
        windowBorderWidth: 1,
        windowControlsBackground: Color(red: 0.96, green: 0.93, blue: 0.86),
        windowControlsBorder: Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.25),
        windowControlsShadow: Color(red: 0.3, green: 0.2, blue: 0.1).opacity(0.15),
        trafficLightClose: Color(red: 0.75, green: 0.3, blue: 0.25),
        trafficLightMinimize: Color(red: 0.78, green: 0.6, blue: 0.25),
        trafficLightZoom: Color(red: 0.35, green: 0.55, blue: 0.35),
        windowHeaderBackground: Color(red: 0.96, green: 0.93, blue: 0.86),
        windowHeaderBorder: Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.2),
        notificationBackground: Color(red: 0.98, green: 0.96, blue: 0.91),
        notificationSecondaryBackground: Color(red: 0.94, green: 0.92, blue: 0.85),
        notificationBorder: Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.4),
        notificationTitle: Color(red: 0.2, green: 0.15, blue: 0.1),
        notificationBody: Color(red: 0.5, green: 0.45, blue: 0.4),
        notificationActionBackground: Color(red: 0.6, green: 0.2, blue: 0.1),
        notificationActionText: .white,
        notificationAccent: Color(red: 0.6, green: 0.2, blue: 0.1),
        sidebarBackground: Color(red: 0.92, green: 0.89, blue: 0.82),
        sidebarItemBackground: Color.clear,
        sidebarItemBackgroundSelected: Color(red: 0.6, green: 0.2, blue: 0.1).opacity(0.15),
        sidebarItemText: Color(red: 0.2, green: 0.15, blue: 0.1),
        sidebarItemTextSelected: Color(red: 0.2, green: 0.15, blue: 0.1),
        sidebarItemIcon: Color(red: 0.4, green: 0.35, blue: 0.3),
        sidebarItemIconSelected: Color(red: 0.2, green: 0.15, blue: 0.1),
        
        // Organic/Ink look: sparse rounded dots with gentle lateral flow
        visualizer: ThemeVisualizerSpec(
            style: .bars,
            barCount: 8,
            barWidth: 5.0,
            barSpacing: 5.0,
            minHeight: 5.0, // Minimum is a circle
            maxHeight: 25.0,
            cornerRadius: 2.5, // Fully rounded
            sensitivitySeed: 1980, // Vintage seed
            amplitudeBoost: 2.5, // High sensitivity for ink dots
            flowIntensity: 0.22,
            flowFrequency: 0.55,
            phaseStep: 0.11
        ),
        miniRecorder: .standard
    )
    
    static func theme(for rawValue: String) -> ThemePalette {
        switch UITheme(rawValue: rawValue) {
        case .liquidGlass:
            return .liquidGlass
        case .cyberpunk:
            return .cyberpunk
        case .vintage:
            return .vintage
        case .basic, .none:
            return .basic
        }
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.basic
    typealias Value = ThemePalette
}

extension EnvironmentValues {
    var theme: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

// MARK: - Component Specs

enum VisualizerStyle: String, Codable, Hashable {
    case bars
    case waveform // Connected line/area graph
}

struct ThemeVisualizerSpec: Codable, Hashable {
    let style: VisualizerStyle
    let barCount: Int
    let barWidth: Double
    let barSpacing: Double
    let minHeight: Double
    let maxHeight: Double
    let cornerRadius: Double
    let sensitivitySeed: Int // Deterministic seed for bar height randomization
    let amplitudeBoost: Double // Multiplier for audio level sensitivity
    let flowIntensity: Double // Extra phase-driven movement layered on top of the base style
    let flowFrequency: Double // Horizontal spacing of the phase wave
    let phaseStep: Double // How quickly the phase advances each update
    
    // Helper to generate a default spec matching the original hardcoded values
    static let standard = ThemeVisualizerSpec(
        style: .bars,
        barCount: 12,
        barWidth: 3.5,
        barSpacing: 2.3,
        minHeight: 5.0,
        maxHeight: 32.0,
        cornerRadius: 1.7,
        sensitivitySeed: 42,
        amplitudeBoost: 1.0,
        flowIntensity: 0.3,
        flowFrequency: 0.9,
        phaseStep: 0.15
    )
}

struct ThemeMiniRecorderSpec: Codable, Hashable {
    let width: Double
    let height: Double
    let contentPaddingHorizontal: Double
    
    static let standard = ThemeMiniRecorderSpec(
        width: 184,
        height: 40,
        contentPaddingHorizontal: 7
    )
}
