import AppKit
import Combine
import Foundation
import SwiftUI
import CoreAudio

// Audio settings are managed by AppSettingsStore
/// Controls system audio management during recording
@MainActor
class MediaController: ObservableObject {
    static let shared = MediaController()
    private var didMuteAudio = false
    private var wasAudioMutedBeforeRecording = false
    private var currentMuteTask: Task<Bool, Never>?
    
    // Reference to centralized settings store
    private weak var appSettings: AppSettingsStore?
    private var cancellables = Set<AnyCancellable>()
    
    // Keep a local copy so audio control still works before AppSettingsStore is injected.
    private var fallbackSystemMuteEnabled = AppSettingsSnapshot.current().isSystemMuteEnabled
    
    /// Whether system mute is enabled - reads from AppSettingsStore if available
    var isSystemMuteEnabled: Bool {
        get { appSettings?.isSystemMuteEnabled ?? fallbackSystemMuteEnabled }
        set {
            objectWillChange.send()
            if let appSettings = appSettings {
                appSettings.isSystemMuteEnabled = newValue
            } else {
                fallbackSystemMuteEnabled = newValue
                UserDefaults.hoah.set(newValue, forKey: "isSystemMuteEnabled")
            }
        }
    }
        
    private init() {}
    
    /// Configure with AppSettingsStore for centralized state management
    func configure(with appSettings: AppSettingsStore) {
        self.appSettings = appSettings
        
        // Subscribe to settings changes
        appSettings.$isSystemMuteEnabled
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    /// Checks if the system audio is currently muted using AppleScript
    private func isSystemAudioMuted() async -> Bool {
        guard let output = await runAppleScript("output muted of (get volume settings)") else {
            return false
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
    
    /// Mutes system audio during recording
    func muteSystemAudio() async -> Bool {
        guard isSystemMuteEnabled else { return false }

        // Cancel any existing mute task and create a new one
        currentMuteTask?.cancel()

        let task = Task<Bool, Never> {
            // First check if audio is already muted
            wasAudioMutedBeforeRecording = await isSystemAudioMuted()
            guard !Task.isCancelled else { return false }

            // If already muted, no need to mute it again
            if wasAudioMutedBeforeRecording {
                return true
            }

            // Otherwise mute the audio
            let success = await executeAppleScript(command: "set volume with output muted")
            guard !Task.isCancelled else { return false }
            didMuteAudio = success
            return success
        }

        currentMuteTask = task
        return await task.value
    }
    
    /// Restores system audio after recording
    func unmuteSystemAudio() async {
        guard isSystemMuteEnabled else { return }

        // Wait for any pending mute operation to complete first
        if let muteTask = currentMuteTask {
            _ = await muteTask.value
        }

        // Only unmute if we actually muted it (and it wasn't already muted)
        if didMuteAudio && !wasAudioMutedBeforeRecording {
            _ = await executeAppleScript(command: "set volume without output muted")
        }

        didMuteAudio = false
        currentMuteTask = nil
    }
    
    /// Executes an AppleScript command off the main thread, returning success/failure.
    @discardableResult
    private func executeAppleScript(command: String) async -> Bool {
        await runAppleScript(command) != nil
    }

    /// Runs an osascript command off the main thread. Returns stdout on success, nil on
    /// failure. Terminates the process if the calling Task is cancelled.
    private func runAppleScript(_ command: String) async -> String? {
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", command]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try process.run()
                        process.waitUntilExit()

                        guard process.terminationStatus == 0 else {
                            continuation.resume(returning: nil)
                            return
                        }
                        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                        continuation.resume(returning: String(data: data, encoding: .utf8))
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}

extension UserDefaults {
    var isSystemMuteEnabled: Bool {
        get { bool(forKey: "isSystemMuteEnabled") }
        set { set(newValue, forKey: "isSystemMuteEnabled") }
    }
}
