import Testing
@testable import HoAh

@Suite("Multi-Press Gesture State Machine")
struct MultiPressGestureStateMachineTests {

    @Test("Case 1: tap to start, tap to stop")
    func case1TapTapNormalMode() {
        var machine = MultiPressGestureStateMachine()

        #expect(machine.handleKeyDown(isRecorderVisible: false) == [.startRecording(.normal), .restartWindowTimer])
        #expect(machine.handleKeyUp().isEmpty)
        #expect(machine.handleWindowExpired().isEmpty)
        #expect(machine.handleKeyDown(isRecorderVisible: true) == [.cancelWindowTimer, .stopRecording])
        #expect(machine.handleKeyUp().isEmpty)
    }

    @Test("Case 2: hold to record, release to stop")
    func case2HoldReleaseNormalMode() {
        var machine = MultiPressGestureStateMachine()

        #expect(machine.handleKeyDown(isRecorderVisible: false) == [.startRecording(.normal), .restartWindowTimer])
        #expect(machine.handleWindowExpired().isEmpty)
        #expect(machine.handleKeyUp() == [.cancelWindowTimer, .stopRecording])
    }

    @Test("Case 3: double-tap to auto-send, tap to stop")
    func case3DoubleTapAutoSendTapStop() {
        var machine = MultiPressGestureStateMachine()

        #expect(machine.handleKeyDown(isRecorderVisible: false) == [.startRecording(.normal), .restartWindowTimer])
        #expect(machine.handleKeyUp().isEmpty)
        #expect(machine.handleKeyDown(isRecorderVisible: true) == [.updateMode(.autoSend), .restartWindowTimer])
        #expect(machine.handleKeyUp().isEmpty)
        #expect(machine.handleWindowExpired().isEmpty)
        #expect(machine.handleKeyDown(isRecorderVisible: true) == [.cancelWindowTimer, .stopRecording])
        #expect(machine.handleKeyUp().isEmpty)
    }

    @Test("Case 4: double-tap then hold, release to stop in auto-send mode")
    func case4DoubleTapHoldAutoSend() {
        var machine = MultiPressGestureStateMachine()

        #expect(machine.handleKeyDown(isRecorderVisible: false) == [.startRecording(.normal), .restartWindowTimer])
        #expect(machine.handleKeyUp().isEmpty)
        #expect(machine.handleKeyDown(isRecorderVisible: true) == [.updateMode(.autoSend), .restartWindowTimer])
        #expect(machine.handleWindowExpired().isEmpty)
        #expect(machine.handleKeyUp() == [.cancelWindowTimer, .stopRecording])
    }

    @Test("Presses beyond two are capped in auto-send mode")
    func pressesBeyondTwoAreCapped() {
        var machine = MultiPressGestureStateMachine()

        #expect(machine.handleKeyDown(isRecorderVisible: false) == [.startRecording(.normal), .restartWindowTimer])
        #expect(machine.handleKeyUp().isEmpty)
        #expect(machine.handleKeyDown(isRecorderVisible: true) == [.updateMode(.autoSend), .restartWindowTimer])
        #expect(machine.handleKeyUp().isEmpty)
        #expect(machine.handleKeyDown(isRecorderVisible: true) == [.restartWindowTimer])
        #expect(machine.handleKeyUp().isEmpty)
    }
}
