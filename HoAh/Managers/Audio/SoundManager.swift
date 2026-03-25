import Foundation
import AVFoundation
import SwiftUI
import Combine

// Audio settings are managed by AppSettingsStore
@MainActor
class SoundManager: ObservableObject {
    static let shared = SoundManager()

    private var startSound: AVAudioPlayer?
    private var stopSound: AVAudioPlayer?
    private var escSound: AVAudioPlayer?
    
    // DEPRECATED: Use AppSettingsStore instead of @AppStorage
    // Keeping for backward compatibility during migration
    @AppStorage("isSoundFeedbackEnabled", store: .hoah) private var legacySoundFeedbackEnabled = true
    
    // Reference to centralized settings store
    private weak var appSettings: AppSettingsStore?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        Task(priority: .background) {
            await setupSounds()
        }
    }
    
    /// Configure with AppSettingsStore for centralized state management
    func configure(with appSettings: AppSettingsStore) {
        self.appSettings = appSettings
        
        // Subscribe to settings changes
        appSettings.$isSoundFeedbackEnabled
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    /// Whether sound feedback is enabled - reads from AppSettingsStore if available
    private var isSoundFeedbackEnabled: Bool {
        appSettings?.isSoundFeedbackEnabled ?? legacySoundFeedbackEnabled
    }

    func setupSounds() async {
        if let startSoundURL = Bundle.main.url(forResource: "recstart", withExtension: "mp3"),
           let stopSoundURL = Bundle.main.url(forResource: "recstop", withExtension: "mp3"),
           let escSoundURL = Bundle.main.url(forResource: "esc", withExtension: "wav") {
            try? await loadSounds(start: startSoundURL, stop: stopSoundURL, esc: escSoundURL)
        }
    }

    private func loadSounds(start startURL: URL, stop stopURL: URL, esc escURL: URL) async throws {
        do {
            startSound = try AVAudioPlayer(contentsOf: startURL)
            stopSound = try AVAudioPlayer(contentsOf: stopURL)
            escSound = try AVAudioPlayer(contentsOf: escURL)

            await MainActor.run {
                startSound?.prepareToPlay()
                stopSound?.prepareToPlay()
                escSound?.prepareToPlay()
            }

            startSound?.volume = 0.4
            stopSound?.volume = 0.4
            escSound?.volume = 0.3
        } catch {
            throw error
        }
    }

    func playStartSound() {
        guard isSoundFeedbackEnabled else { return }
        startSound?.volume = 0.4
        startSound?.play()
    }

    func playStopSound() {
        guard isSoundFeedbackEnabled else { return }
        stopSound?.volume = 0.4
        stopSound?.play()
    }
    
    func playEscSound() {
        guard isSoundFeedbackEnabled else { return }
        escSound?.volume = 0.3
        escSound?.play()
    }
    
    var isEnabled: Bool {
        get { appSettings?.isSoundFeedbackEnabled ?? legacySoundFeedbackEnabled }
        set {
            objectWillChange.send()
            if let appSettings = appSettings {
                appSettings.isSoundFeedbackEnabled = newValue
            } else {
                legacySoundFeedbackEnabled = newValue
            }
        }
    }
} 
