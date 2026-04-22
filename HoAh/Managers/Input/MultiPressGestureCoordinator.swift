import Foundation
import AppKit

/// Owns the scheduling shell around `MultiPressGestureStateMachine`: the
/// gesture window timer, the stuck-key watchdog, and the right-Option key
/// state. Keeps HotkeyManager focused on registration/dispatch.
///
/// Timing and side-effect surfaces are injected via protocols so the
/// coordinator can be unit-tested without a real event tap, a real
/// `WhisperState`, or real `Task.sleep` delays.
///
/// See docs/specs/MULTI_PRESS_GESTURE.md for the gesture semantics.
@MainActor
final class MultiPressGestureCoordinator {
    private let recorderController: GestureRecorderController
    private let scheduler: GestureScheduler
    private let modifierFlagsReader: ModifierFlagsReading

    private var stateMachine = MultiPressGestureStateMachine()
    private var isKeyHeld = false

    private var windowTask: Task<Void, Never>?
    private let windowDuration: TimeInterval = 0.5

    // Watchdog that recovers from a lost keyUp (app backgrounded, system sleep,
    // event-tap hiccup). If the key has supposedly been held this long but the
    // real modifier flags say otherwise, synthesize a keyUp to unstick state.
    private var watchdogTask: Task<Void, Never>?
    private let maxKeyHoldDuration: TimeInterval = 10.0

    init(
        recorderController: GestureRecorderController,
        scheduler: GestureScheduler = LiveGestureScheduler(),
        modifierFlagsReader: ModifierFlagsReading = LiveModifierFlagsReading()
    ) {
        self.recorderController = recorderController
        self.scheduler = scheduler
        self.modifierFlagsReader = modifierFlagsReader
    }

    func handleRightOptionStateChange(isPressed: Bool) async {
        guard isPressed != isKeyHeld else { return }
        isKeyHeld = isPressed
        if isPressed {
            scheduleMaxHoldWatchdog()
        } else {
            cancelMaxHoldWatchdog()
        }

        let actions = isPressed
            ? stateMachine.handleKeyDown(isRecorderVisible: recorderController.isMiniRecorderVisible)
            : stateMachine.handleKeyUp()
        await applyActions(actions)
    }

    func handleRecorderHidden() {
        cancelWindowTimer()
        stateMachine.reset()
    }

    func reset() {
        isKeyHeld = false
        cancelWindowTimer()
        cancelMaxHoldWatchdog()
        stateMachine.reset()
    }

    deinit {
        // Task.cancel() is thread-safe and these are Sendable stored
        // properties, so this is safe from the non-isolated deinit.
        windowTask?.cancel()
        watchdogTask?.cancel()
    }

    // MARK: - Action Application

    private func applyActions(_ actions: [MultiPressGestureAction]) async {
        for action in actions {
            switch action {
            case .startRecording(let mode):
                guard recorderController.canProcessHotkeyAction else {
                    cancelWindowTimer()
                    stateMachine.reset()
                    return
                }
                recorderController.recordingMode = mode
                recorderController.handleToggleMiniRecorder()
            case .updateMode(let mode):
                recorderController.recordingMode = mode
            case .restartWindowTimer:
                resetWindowTimer()
            case .cancelWindowTimer:
                cancelWindowTimer()
            case .stopRecording:
                cancelWindowTimer()
                guard recorderController.canProcessHotkeyAction else {
                    stateMachine.reset()
                    return
                }
                recorderController.handleToggleMiniRecorder()
                stateMachine.reset()
            }
        }
    }

    // MARK: - Window Timer

    private func resetWindowTimer() {
        cancelWindowTimer()
        windowTask = Task { [weak self, scheduler, windowDuration] in
            try? await scheduler.sleep(nanoseconds: UInt64(windowDuration * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            let actions = self.stateMachine.handleWindowExpired()
            await self.applyActions(actions)
        }
    }

    private func cancelWindowTimer() {
        windowTask?.cancel()
        windowTask = nil
    }

    // MARK: - Max-Hold Watchdog

    private func scheduleMaxHoldWatchdog() {
        cancelMaxHoldWatchdog()
        watchdogTask = Task { [weak self, scheduler, maxKeyHoldDuration] in
            try? await scheduler.sleep(nanoseconds: UInt64(maxKeyHoldDuration * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            await self.recoverFromStuckKeyIfNeeded()
        }
    }

    private func cancelMaxHoldWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    private func recoverFromStuckKeyIfNeeded() async {
        guard isKeyHeld else { return }
        let realFlags = modifierFlagsReader.currentModifierFlags()
        guard !HotkeyOption.rightOption.isPressed(in: realFlags) else {
            // Key is genuinely still held; rearm for another cycle.
            scheduleMaxHoldWatchdog()
            return
        }
        // Real state says released but we never saw the keyUp — synthesize one.
        await handleRightOptionStateChange(isPressed: false)
    }
}
