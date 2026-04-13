import Foundation

enum MultiPressGestureAction: Equatable {
    case startRecording(RecordingMode)
    case updateMode(RecordingMode)
    case restartWindowTimer
    case cancelWindowTimer
    case stopRecording
}

struct MultiPressGestureStateMachine {
    private enum StopBehavior {
        case none
        case nextPress
        case keyRelease
    }

    private(set) var mode: RecordingMode = .normal
    private var pressCount = 0
    private var isWindowOpen = false
    private var stopBehavior: StopBehavior = .none
    private var currentKeyDown = false
    private var shouldIgnoreNextKeyUp = false

    mutating func reset() {
        mode = .normal
        pressCount = 0
        isWindowOpen = false
        stopBehavior = .none
        currentKeyDown = false
        shouldIgnoreNextKeyUp = false
    }

    mutating func handleKeyDown(isRecorderVisible: Bool) -> [MultiPressGestureAction] {
        guard !currentKeyDown else { return [] }
        currentKeyDown = true

        if isWindowOpen {
            switch pressCount {
            case 1:
                pressCount = 2
                mode = .autoSend
                return [.updateMode(.autoSend), .restartWindowTimer]
            default:
                // Presses beyond 2 stay in auto-send mode rather than toggling off early.
                pressCount = 2
                return [.restartWindowTimer]
            }
        }

        if stopBehavior == .nextPress {
            return stopOnKeyDown()
        }

        if !isRecorderVisible {
            mode = .normal
            pressCount = 1
            isWindowOpen = true
            stopBehavior = .none
            shouldIgnoreNextKeyUp = false
            return [.startRecording(.normal), .restartWindowTimer]
        }

        return []
    }

    mutating func handleKeyUp() -> [MultiPressGestureAction] {
        guard currentKeyDown else { return [] }
        currentKeyDown = false

        if shouldIgnoreNextKeyUp {
            shouldIgnoreNextKeyUp = false
            return []
        }

        if isWindowOpen {
            return []
        }

        if stopBehavior == .keyRelease {
            return stopOnKeyUp()
        }

        return []
    }

    mutating func handleWindowExpired() -> [MultiPressGestureAction] {
        guard isWindowOpen else { return [] }
        isWindowOpen = false
        stopBehavior = currentKeyDown ? .keyRelease : .nextPress
        return []
    }

    private mutating func stopOnKeyDown() -> [MultiPressGestureAction] {
        isWindowOpen = false
        stopBehavior = .none
        pressCount = 0
        shouldIgnoreNextKeyUp = true
        return [.cancelWindowTimer, .stopRecording]
    }

    private mutating func stopOnKeyUp() -> [MultiPressGestureAction] {
        isWindowOpen = false
        stopBehavior = .none
        pressCount = 0
        return [.cancelWindowTimer, .stopRecording]
    }
}
