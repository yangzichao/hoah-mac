import SwiftUI
import SwiftData
import KeyboardShortcuts
import AVFoundation

// ViewType enum with all cases
enum ViewType: String, CaseIterable, Identifiable {
    case metrics = "History"
    case aiMode = "AI Action"
    case models = "Dictation Models"
    case permissions = "Permissions"
    case audioInput = "Audio Input"
    case settings = "Settings"
    case help = "Help"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .metrics: return "clock.arrow.circlepath"
        case .models: return "waveform"
        case .aiMode: return "wand.and.stars"
        case .permissions: return "shield.fill"
        case .audioInput: return "mic.fill"
        case .settings: return "gearshape.fill"
        case .help: return "questionmark.circle"
        }
    }
}

// MARK: - Sidebar Button Builder
private func sidebarButton(
    theme: ThemePalette,
    isSelected: Bool,
    title: String,
    icon: String?,
    iconImage: NSImage?,
    showWarning: Bool,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        HStack(spacing: 12) {
            if let iconImage {
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .cornerRadius(8)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)
                    .foregroundColor(isSelected ? theme.sidebarItemIconSelected : theme.sidebarItemIcon)
            }
            
            Text(LocalizedStringKey(title))
                .font(title == "HoAh" ? theme.typography.sidebarTitle : theme.typography.sidebarItem)
                .foregroundColor(isSelected ? theme.sidebarItemTextSelected : theme.sidebarItemText)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            
            Spacer()
            
            if showWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.statusWarning)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? theme.sidebarItemBackgroundSelected : Color.clear)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 8)
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.theme) private var theme
    @State private var selectedView: ViewType? = .metrics
    @StateObject private var permissionManager = PermissionManager()
    // DEPRECATED: Use AppSettingsStore instead of @AppStorage
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    private var visibleViewTypes: [ViewType] {
        ViewType.allCases
    }

    var body: some View {
        ZStack {
             NavigationSplitView {
                ZStack {
                    theme.sidebarBackground.ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Metrics / Home
                            sidebarButton(
                                theme: theme,
                                isSelected: selectedView == .metrics,
                                title: "History",
                                icon: ViewType.metrics.icon,
                                iconImage: nil,
                                showWarning: false
                            ) { selectedView = .metrics }
                            
                            ForEach(visibleViewTypes.filter { $0 != .metrics }) { viewType in
                                sidebarButton(
                                    theme: theme,
                                    isSelected: selectedView == viewType,
                                    title: viewType.rawValue,
                                    icon: viewType.icon,
                                    iconImage: nil,
                                    showWarning:
                                        (viewType == .permissions && hasPermissionIssues) ||
                                        (viewType == .models && hasModelIssues) ||
                                        (viewType == .aiMode && hasAIModeIssues)
                                ) { selectedView = viewType }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .scrollIndicators(.hidden)
                    .navigationTitle("HoAh")
                }
                .frame(minWidth: 230, idealWidth: 240, maxWidth: 280)
                .navigationSplitViewColumnWidth(min: 230, ideal: 240, max: 280)
            } detail: {
            if let selectedView = selectedView {
                detailView(for: selectedView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(LocalizedStringKey(selectedView.rawValue))
            } else {
                Text("Select a view")
                    .foregroundColor(theme.textSecondary)
            }
            }
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 940, minHeight: 730)
            .background(
                ZStack {
                    if appSettings.uiTheme == "liquidGlass" {
                        // Layer 1: The "Liquid" - Living ambient light
                        AmbientFluidBackground()
                        
                        // Layer 2: The "Glass" - Frosting the light
                        Rectangle()
                            .fill(.regularMaterial)
                            .ignoresSafeArea()
                    } else if appSettings.uiTheme == "vintage" {
                        // Layer 1: Base Warm Paper
                        theme.windowBackground.ignoresSafeArea()
                        
                        // Layer 2: Uneven aging/stains (Simulated Paper)
                        PaperBackgroundOverlay()
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    } else {
                        theme.windowBackground
                            .ignoresSafeArea()
                    }
                }
            )
            }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { notification in
            if let destination = notification.userInfo?["destination"] as? String {
                switch destination {
                case "Settings":
                    selectedView = .settings
                case "Dictation Models", "AI Models":
                    selectedView = .models
                case "History":
                    selectedView = .metrics
                case "Permissions":
                    selectedView = .permissions
                case "AI Action", "AI Mode", "Enhancement":
                    selectedView = .aiMode
                case "HoAh", "Dashboard":
                    selectedView = .metrics
                default:
                    break
                }
            }
        }
    }
    
    private var hasPermissionIssues: Bool {
        permissionManager.audioPermissionStatus != .authorized ||
        !permissionManager.isAccessibilityEnabled
    }
    
    private var hasModelIssues: Bool {
        whisperState.currentTranscriptionModel == nil
    }
    
    private var hasAIModeIssues: Bool {
        appSettings.validAIConfigurations.isEmpty
    }
    
    @ViewBuilder
    private func detailView(for viewType: ViewType) -> some View {
        switch viewType {
        case .metrics:
            MetricsView()
        case .models:
            ModelManagementView(whisperState: whisperState)
        case .aiMode:
            EnhancementSettingsView()
        case .audioInput:
            AudioInputSettingsView()
        case .settings:
            SettingsView()
                .environmentObject(whisperState)
        case .permissions:
            PermissionsView()
        case .help:
            HelpView()
        }
    }
}

// MARK: - Ambient Fluid Background
struct AmbientFluidBackground: View {
    @State private var animate = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        ZStack {
            // Primary Orb (Top Left)
            Circle()
                .fill(theme.accentColor.opacity(0.25))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(x: animate ? -100 : 100, y: animate ? -100 : 0)
                .scaleEffect(animate ? 1.1 : 0.9)
            
            // Secondary Orb (Bottom Right)
            Circle()
                .fill(theme.accentColor.opacity(0.15))
                .frame(width: 500, height: 500)
                .blur(radius: 80)
                .offset(x: animate ? 150 : -50, y: animate ? 150 : 50)
                
            // Accent Orb (Floating)
            Circle()
                .fill(theme.glowColor.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? -50 : 150, y: animate ? 50 : -100)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

 
