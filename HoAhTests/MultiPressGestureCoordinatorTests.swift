import Testing
import Foundation
import AppKit
@testable import HoAh

// MARK: - Fakes

/// Records every `sleep(nanoseconds:)` request and suspends until the test
/// explicitly fires the oldest pending sleep. Lets tests drive the
/// coordinator's window and watchdog timers deterministically.
final class ControllableScheduler: GestureScheduler, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Error>] = []
    private var requests: [UInt64] = []

    var sleepRequests: [UInt64] {
        lock.lock(); defer { lock.unlock() }
        return requests
    }

    var pendingCount: Int {
        lock.lock(); defer { lock.unlock() }
        return continuations.count
    }

    func sleep(nanoseconds: UInt64) async throws {
        lock.lock()
        requests.append(nanoseconds)
        lock.unlock()
        try await withCheckedThrowingContinuation { cont in
            lock.lock()
            continuations.append(cont)
            lock.unlock()
        }
    }

    /// Resume the oldest pending sleep as if it completed normally.
    @discardableResult
    func fireNext() -> Bool {
        lock.lock()
        guard !continuations.isEmpty else {
            lock.unlock()
            return false
        }
        let cont = continuations.removeFirst()
        lock.unlock()
        cont.resume()
        return true
    }
}

@MainActor
final class FakeModifierFlagsReader: ModifierFlagsReading {
    var flags: NSEvent.ModifierFlags = []

    func currentModifierFlags() -> NSEvent.ModifierFlags { flags }
}

@MainActor
final class FakeRecorderController: GestureRecorderController {
    var isMiniRecorderVisible: Bool = false
    var recordingMode: RecordingMode = .normal
    var canProcessHotkeyAction: Bool = true
    var toggleCount = 0

    func handleToggleMiniRecorder() {
        toggleCount += 1
        // Match production: toggling from hidden shows the recorder.
        isMiniRecorderVisible.toggle()
    }
}

// MARK: - Helpers

/// Yields a few times so Tasks spawned inside the coordinator have a chance
/// to reach their first suspension point (the scheduler sleep).
private func drain() async {
    for _ in 0..<8 { await Task.yield() }
}

private let watchdogNanos: UInt64 = 10_000_000_000
private let windowNanos: UInt64 = 500_000_000

// MARK: - Tests

@MainActor
@Suite("Multi-Press Gesture Coordinator")
struct MultiPressGestureCoordinatorTests {

    @Test("Key down with recorder hidden starts recording and arms watchdog + window")
    func keyDownStartsAndArmsTimers() async {
        let scheduler = ControllableScheduler()
        let flags = FakeModifierFlagsReader()
        let controller = FakeRecorderController()
        let coordinator = MultiPressGestureCoordinator(
            recorderController: controller,
            scheduler: scheduler,
            modifierFlagsReader: flags
        )

        await coordinator.handleRightOptionStateChange(isPressed: true)
        await drain()

        #expect(controller.toggleCount == 1)
        #expect(controller.recordingMode == .normal)
        #expect(controller.isMiniRecorderVisible == true)
        // Watchdog arms immediately on keyDown; window arms via state-machine action.
        #expect(scheduler.sleepRequests == [watchdogNanos, windowNanos])
        #expect(scheduler.pendingCount == 2)
    }

    @Test("Second press inside window flips mode to autoSend without extra toggle")
    func secondPressFlipsToAutoSend() async {
        let scheduler = ControllableScheduler()
        let flags = FakeModifierFlagsReader()
        let controller = FakeRecorderController()
        let coordinator = MultiPressGestureCoordinator(
            recorderController: controller,
            scheduler: scheduler,
            modifierFlagsReader: flags
        )

        await coordinator.handleRightOptionStateChange(isPressed: true)  // first down → startRecording
        await drain()
        await coordinator.handleRightOptionStateChange(isPressed: false) // first up (inside window)
        await drain()
        await coordinator.handleRightOptionStateChange(isPressed: true)  // second down → updateMode(autoSend)
        await drain()

        #expect(controller.toggleCount == 1)          // still just the initial start
        #expect(controller.recordingMode == .autoSend)
    }

    @Test("Watchdog fires while flag still pressed → rearms, does not synthesize keyUp")
    func watchdogRearmsWhenFlagStillHeld() async {
        let scheduler = ControllableScheduler()
        let flags = FakeModifierFlagsReader()
        flags.flags = NSEvent.ModifierFlags(rawValue: 0x00000040) // rightOption device mask
        let controller = FakeRecorderController()
        let coordinator = MultiPressGestureCoordinator(
            recorderController: controller,
            scheduler: scheduler,
            modifierFlagsReader: flags
        )

        await coordinator.handleRightOptionStateChange(isPressed: true)
        await drain()
        let initialToggle = controller.toggleCount
        #expect(scheduler.sleepRequests == [watchdogNanos, windowNanos])

        // Fire watchdog sleep.
        scheduler.fireNext()
        await drain()

        // A fresh watchdog sleep must have been scheduled (rearm), and nothing
        // else fired on the recorder.
        #expect(scheduler.sleepRequests == [watchdogNanos, windowNanos, watchdogNanos])
        #expect(controller.toggleCount == initialToggle)
    }

    @Test("Watchdog fires with flag released → synthesizes keyUp, no rearm")
    func watchdogSynthesizesKeyUpWhenFlagReleased() async {
        let scheduler = ControllableScheduler()
        let flags = FakeModifierFlagsReader()
        flags.flags = NSEvent.ModifierFlags(rawValue: 0x00000040)
        let controller = FakeRecorderController()
        let coordinator = MultiPressGestureCoordinator(
            recorderController: controller,
            scheduler: scheduler,
            modifierFlagsReader: flags
        )

        await coordinator.handleRightOptionStateChange(isPressed: true)
        await drain()

        // Simulate that the real modifier state now shows the key released.
        flags.flags = []

        scheduler.fireNext() // fire watchdog
        await drain()

        // Recovery path should NOT schedule another watchdog (isKeyHeld is now false).
        let requestsAfter = scheduler.sleepRequests
        #expect(requestsAfter == [watchdogNanos, windowNanos])
        // Recorder was only toggled on the original keyDown; synthesized keyUp
        // inside an open window produces no action.
        #expect(controller.toggleCount == 1)
    }

    @Test("Recorder hidden cancels window timer but keeps watchdog alive")
    func recorderHiddenCancelsWindowOnly() async {
        let scheduler = ControllableScheduler()
        let flags = FakeModifierFlagsReader()
        let controller = FakeRecorderController()
        let coordinator = MultiPressGestureCoordinator(
            recorderController: controller,
            scheduler: scheduler,
            modifierFlagsReader: flags
        )

        await coordinator.handleRightOptionStateChange(isPressed: true)
        await drain()
        #expect(scheduler.pendingCount == 2) // watchdog + window

        coordinator.handleRecorderHidden()
        await drain()

        // Window task cancelled → its continuation stays in the fake but the
        // live task is cancelled; we can only assert that the window-expired
        // side effect does not occur. Scheduler request history is unchanged.
        #expect(scheduler.sleepRequests == [watchdogNanos, windowNanos])
    }

    @Test("canProcessHotkeyAction=false blocks startRecording")
    func blockedWhenCannotProcess() async {
        let scheduler = ControllableScheduler()
        let flags = FakeModifierFlagsReader()
        let controller = FakeRecorderController()
        controller.canProcessHotkeyAction = false
        let coordinator = MultiPressGestureCoordinator(
            recorderController: controller,
            scheduler: scheduler,
            modifierFlagsReader: flags
        )

        await coordinator.handleRightOptionStateChange(isPressed: true)
        await drain()

        #expect(controller.toggleCount == 0)
        // Watchdog arms regardless (tied to key state, not dispatch eligibility).
        #expect(scheduler.sleepRequests == [watchdogNanos])
    }
}
