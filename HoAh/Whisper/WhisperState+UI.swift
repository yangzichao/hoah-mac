import Foundation
import SwiftUI
import os
import AppKit

// MARK: - UI Management Extension
extension WhisperState {
    
    // MARK: - Recorder Panel Management
    
    func showRecorderPanel() {
        logger.notice("📱 Showing \(self.recorderType) recorder")
        guard let appSettings = appSettings else {
            logger.error("AppSettingsStore missing; cannot show recorder panel")
            return
        }
        
        if recorderType == "notch" {
            if notchWindowManager == nil {
                notchWindowManager = NotchWindowManager(whisperState: self, recorder: recorder, appSettings: appSettings)
            }
            notchWindowManager?.show()
        } else {
            if miniWindowManager == nil {
                miniWindowManager = MiniWindowManager(whisperState: self, recorder: recorder, appSettings: appSettings)
            }
            miniWindowManager?.show()
        }
    }
    
    func hideRecorderPanel() {
        if recorderType == "notch" {
            notchWindowManager?.hide()
        } else {
            miniWindowManager?.hide()
        }
    }
    
    // MARK: - Mini Recorder Management
    
    func toggleMiniRecorder(mode: RecordingMode = .normal) async {
        if isMiniRecorderVisible {
            if recordingState == .recording {
                await toggleRecord()
            } else {
                await cancelRecording()
            }
        } else {
            SoundManager.shared.playStartSound()

            await toggleRecord()

            await MainActor.run {
                isMiniRecorderVisible = true // This will call showRecorderPanel() via didSet
            }
        }
    }
    
    func dismissMiniRecorder() async {
        if recordingState == .busy { return }

        let wasRecording = recordingState == .recording

        await MainActor.run {
            self.recordingState = .busy
        }
        
        if wasRecording {
            cancelRecordingTimeout()
            await recorder.stopRecording()
        }
        
        hideRecorderPanel()
        
        await MainActor.run {
            isMiniRecorderVisible = false
        }
        
        await cleanupModelResources()
        
        await MainActor.run {
            recordingMode = .normal
            recordingState = .idle
        }
    }

    func resetOnLaunch() async {
        logger.notice("🔄 Resetting recording state on launch")
        cancelRecordingTimeout()
        await recorder.stopRecording()
        hideRecorderPanel()
        await MainActor.run {
            isMiniRecorderVisible = false
            shouldCancelRecording = false
            miniRecorderError = nil
            recordingMode = .normal
            recordingState = .idle
        }
        await cleanupModelResources()
    }
    
    func cancelRecording() async {
        SoundManager.shared.playEscSound()
        cancelRecordingTimeout()
        shouldCancelRecording = true
        await dismissMiniRecorder()
    }
    
    // MARK: - Notification Handling
    
    func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleMiniRecorder), name: .toggleMiniRecorder, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDismissMiniRecorder), name: .dismissMiniRecorder, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePromptChange), name: .promptDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWakeFromSleep), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    @objc public func handleToggleMiniRecorder() {
        guard !isTogglingRecorder else { return }
        isTogglingRecorder = true
        Task {
            defer { isTogglingRecorder = false }
            await toggleMiniRecorder(mode: recordingMode)
        }
    }

    @objc public func handleDismissMiniRecorder() {
        guard !isTogglingRecorder else { return }
        isTogglingRecorder = true
        Task {
            defer { isTogglingRecorder = false }
            await dismissMiniRecorder()
        }
    }
    
    @objc func handlePromptChange() {
        // Update the whisper context with the new prompt
        Task {
            await updateContextPrompt()
        }
    }
    
    private func updateContextPrompt() async {
        // Always reload the prompt from UserDefaults to ensure we have the latest
        let currentPrompt = UserDefaults.hoah.string(forKey: "TranscriptionPrompt") ?? whisperPrompt.transcriptionPrompt
        
        if let context = whisperContext {
            await context.setPrompt(currentPrompt)
        }
    }
    
    @objc private func handleWakeFromSleep(_ notification: Notification) {
        warmupActiveLocalModel(reason: "wake from sleep", force: true)
    }
    
    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        warmupActiveLocalModel(reason: "app became active")
    }
} 
