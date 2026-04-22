import Foundation

/// Narrow surface of `WhisperState` that the multi-press gesture coordinator
/// actually depends on. Exists so tests can provide a lightweight fake
/// instead of constructing a real `WhisperState`.
@MainActor
protocol GestureRecorderController: AnyObject {
    var isMiniRecorderVisible: Bool { get }
    var recordingMode: RecordingMode { get set }
    var canProcessHotkeyAction: Bool { get }
    func handleToggleMiniRecorder()
}

extension WhisperState: GestureRecorderController {}
