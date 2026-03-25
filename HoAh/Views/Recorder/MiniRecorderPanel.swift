import SwiftUI
import AppKit

class MiniRecorderPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    private static let shadowPaddingWidth: CGFloat = 60
    private static let shadowPaddingHeight: CGFloat = 60
    private static let bottomPadding: CGFloat = 24
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }
    
    private func configurePanel() {
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = true
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
    }
    
    static func contentSize(
        theme: ThemePalette,
        selectedModel: (any TranscriptionModel)?
    ) -> CGSize {
        let baseWidth = CGFloat(theme.miniRecorder.width)
        let baseHeight = CGFloat(theme.miniRecorder.height)
        let extraWidth: CGFloat = (selectedModel?.usesRealtimeStreaming == true) ? 56 : 0

        return CGSize(width: baseWidth + extraWidth, height: baseHeight)
    }

    static func calculateWindowMetrics(
        theme: ThemePalette,
        selectedModel: (any TranscriptionModel)?
    ) -> NSRect {
        guard let screen = NSScreen.main else {
            let size = contentSize(theme: theme, selectedModel: selectedModel)
            return NSRect(
                x: 0,
                y: 0,
                width: size.width + shadowPaddingWidth,
                height: size.height + shadowPaddingHeight
            )
        }

        let contentSize = contentSize(theme: theme, selectedModel: selectedModel)
        let width = contentSize.width + shadowPaddingWidth
        let height = contentSize.height + shadowPaddingHeight

        let visibleFrame = screen.visibleFrame
        let centerX = visibleFrame.midX
        let xPosition = centerX - (width / 2)
        let yPosition = visibleFrame.minY + bottomPadding

        return NSRect(
            x: xPosition,
            y: yPosition,
            width: width,
            height: height
        )
    }
    
    func show(theme: ThemePalette, selectedModel: (any TranscriptionModel)?) {
        let metrics = MiniRecorderPanel.calculateWindowMetrics(theme: theme, selectedModel: selectedModel)
        setFrame(metrics, display: true)
        orderFrontRegardless()
    }
    
    func hide(completion: @escaping () -> Void) {
        completion()
    }
} 
