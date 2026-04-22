import Foundation

extension WhisperState {
    /// True when the whisper pipeline is in a state that can accept a new
    /// toggle/start/stop from a hotkey. Shared by `HotkeyManager` and
    /// `MultiPressGestureCoordinator` so the set of blocking states stays
    /// defined in exactly one place.
    var canProcessHotkeyAction: Bool {
        recordingState != .finishing &&
        recordingState != .transcribing &&
        recordingState != .enhancing &&
        recordingState != .busy
    }
}
