import SwiftUI
import SwiftData
import AppKit

@MainActor
class MiniWindowManager: ObservableObject {
    @Published var isVisible = false
    private var windowController: NSWindowController?
    private var miniPanel: MiniRecorderPanel?
    private let whisperState: WhisperState
    private let recorder: Recorder
    private let appSettings: AppSettingsStore

    private var currentTheme: ThemePalette {
        ThemePalette.theme(for: appSettings.uiTheme)
    }
    
    init(whisperState: WhisperState, recorder: Recorder, appSettings: AppSettingsStore) {
        self.whisperState = whisperState
        self.recorder = recorder
        self.appSettings = appSettings
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideNotification),
            name: NSNotification.Name("HideMiniRecorder"),
            object: nil
        )
    }
    
    @objc private func handleHideNotification() {
        hide()
    }
    func show() {
        if isVisible { return }

        let activeScreen = NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens[0]

        initializeWindow(screen: activeScreen)
        self.isVisible = true
        miniPanel?.show(theme: currentTheme, selectedModel: whisperState.currentTranscriptionModel)
    }

    func hide() {
        guard isVisible else { return }

        self.isVisible = false
        self.miniPanel?.hide { [weak self] in
            guard let self = self else { return }
            self.deinitializeWindow()
        }
    }
    
    private func initializeWindow(screen: NSScreen) {
        deinitializeWindow()
        
        let metrics = MiniRecorderPanel.calculateWindowMetrics(
            theme: currentTheme,
            selectedModel: whisperState.currentTranscriptionModel
        )
        let panel = MiniRecorderPanel(contentRect: metrics)
        
        guard let enhancementService = whisperState.enhancementService else {
            whisperState.logger.error("Missing enhancementService while creating MiniRecorderView")
            return
        }
        
        let miniRecorderView = MiniRecorderView(whisperState: whisperState, recorder: recorder)
            .environmentObject(self)
            .environmentObject(appSettings)
            .environmentObject(enhancementService)
            .environment(\.theme, currentTheme)
            .modelContext(whisperState.modelContext)
        
        let hostingController = NSHostingController(rootView: miniRecorderView)
        panel.contentView = hostingController.view
        
        self.miniPanel = panel
        self.windowController = NSWindowController(window: panel)
        
        panel.orderFrontRegardless()
    }
    
    private func deinitializeWindow() {
        miniPanel?.orderOut(nil)
        windowController?.close()
        windowController = nil
        miniPanel = nil
    }
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func updateWindowMetricsIfNeeded() {
        guard isVisible, let panel = miniPanel else { return }
        let metrics = MiniRecorderPanel.calculateWindowMetrics(
            theme: currentTheme,
            selectedModel: whisperState.currentTranscriptionModel
        )
        panel.setFrame(metrics, display: true, animate: true)
    }
}
