import Foundation
import AppKit
import AVFoundation

class SystemInfoService {
    static let shared = SystemInfoService()

    private init() {}

    func getSystemInfoString() -> String {
        let info = """
        === HoAh SYSTEM INFORMATION ===
        Generated: \(Date().formatted(date: .long, time: .standard))

        APP INFORMATION:
        App Version: \(getAppVersion())
        Build Version: \(getBuildVersion())
        License Status: \(getLicenseStatus())

        OPERATING SYSTEM:
        macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)

        HARDWARE INFORMATION:
        Device Model: \(getMacModel())
        CPU: \(getCPUInfo())
        Memory: \(getMemoryInfo())
        Architecture: \(getArchitecture())

        AUDIO SETTINGS:
        Input Mode: \(getAudioInputMode())
        Current Audio Device: \(getCurrentAudioDevice())
        Available Audio Devices: \(getAvailableAudioDevices())

        HOTKEY SETTINGS:
        Primary Hotkey: \(getPrimaryHotkey())
        Secondary Hotkey: \(getSecondaryHotkey())

        TRANSCRIPTION SETTINGS:
        Selected Model: \(getCurrentTranscriptionModel())
        Selected Language: \(getCurrentLanguage())
        AI Action: \(getAIEnhancementStatus())
        AI Provider: \(getAIProvider())
        AI Model: \(getAIModel())

        PERMISSIONS:
        Accessibility: \(getAccessibilityStatus())
        Microphone: \(getMicrophoneStatus())
        """

        return info
    }

    func copySystemInfoToClipboard() {
        let info = getSystemInfoString()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(info, forType: .string)
    }

    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private func getBuildVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    private func getCPUInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    private func getMemoryInfo() -> String {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        return ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
    }

    private func getArchitecture() -> String {
        #if arch(x86_64)
            return "Intel x86_64"
        #elseif arch(arm64)
            return "Apple Silicon (ARM64)"
        #else
            return "Unknown"
        #endif
    }

    private func getAudioInputMode() -> String {
        if let mode = UserDefaults.hoah.audioInputModeRawValue,
           let audioMode = AudioInputMode(rawValue: mode) {
            return audioMode.rawValue
        }
        return "System Default"
    }

    private func getCurrentAudioDevice() -> String {
        let audioManager = AudioDeviceManager.shared
        let deviceID = audioManager.getCurrentDevice()
        if deviceID != 0,
           let deviceName = audioManager.getDeviceName(deviceID: deviceID) {
            return deviceName
        }
        return "System Default"
    }

    private func getAvailableAudioDevices() -> String {
        let devices = AudioDeviceManager.shared.availableDevices
        if devices.isEmpty {
            return "None detected"
        }
        return devices.map { $0.name }.joined(separator: ", ")
    }

    private func getPrimaryHotkey() -> String {
        if let hotkeyRaw = UserDefaults.hoah.string(forKey: "selectedHotkey1"),
           let hotkey = HotkeyOption(rawValue: hotkeyRaw) {
            return hotkey.displayName
        }
        return "Right Command"
    }

    private func getSecondaryHotkey() -> String {
        if let hotkeyRaw = UserDefaults.hoah.string(forKey: "selectedHotkey2"),
           let hotkey = HotkeyOption(rawValue: hotkeyRaw) {
            return hotkey.displayName
        }
        return "None"
    }

    private func getCurrentTranscriptionModel() -> String {
        if let modelName = UserDefaults.hoah.string(forKey: "CurrentTranscriptionModel") {
            if let model = PredefinedModels.models.first(where: { $0.name == modelName }) {
                return model.displayName
            }
            return modelName
        }
        return "No model selected"
    }

    private func getAIEnhancementStatus() -> String {
        let enhancementEnabled = UserDefaults.hoah.bool(forKey: "isAIEnhancementEnabled")
        return enhancementEnabled ? "Enabled" : "Disabled"
    }

    private func getAIProvider() -> String {
        if let providerRaw = UserDefaults.hoah.string(forKey: "selectedAIProvider") {
            return providerRaw
        }
        return "None selected"
    }

    private func getAIModel() -> String {
        if let providerRaw = UserDefaults.hoah.string(forKey: "selectedAIProvider") {
            let modelKey = "\(providerRaw)SelectedModel"
            if let savedModel = UserDefaults.hoah.string(forKey: modelKey), !savedModel.isEmpty {
                return savedModel
            }
            return "Default (\(providerRaw))"
        }
        return "None selected"
    }
    private func getAccessibilityStatus() -> String {
        return AXIsProcessTrusted() ? "Granted" : "Not Granted"
    }

    private func getMicrophoneStatus() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    private func getLicenseStatus() -> String {
        return "Licensed (Fork build)"
    }

    private func getCurrentLanguage() -> String {
        AppSettingsSnapshot.current().selectedLanguage
    }

}

@MainActor
final class MemoryPressureMonitor: ObservableObject {
    enum Level: Equatable {
        case normal
        case warning
        case critical
    }

    static let shared = MemoryPressureMonitor()

    @Published private(set) var currentLevel: Level = .normal

    private var pressureSource: DispatchSourceMemoryPressure?
    private var lastRecordingNotificationAt: Date?
    private let notificationCooldown: TimeInterval = 5 * 60

    private init() {}

    func startMonitoring() {
        guard pressureSource == nil else { return }

        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.handlePressureEvent(source.data)
        }

        source.resume()
        pressureSource = source
    }

    func stopMonitoring() {
        pressureSource?.cancel()
        pressureSource = nil
        currentLevel = .normal
        lastRecordingNotificationAt = nil
    }

    func notifyIfElevatedForRecordingStart() {
        guard currentLevel != .normal else { return }

        let now = Date()
        if let lastRecordingNotificationAt,
           now.timeIntervalSince(lastRecordingNotificationAt) < notificationCooldown {
            return
        }

        lastRecordingNotificationAt = now

        let title: String
        switch currentLevel {
        case .warning:
            title = NSLocalizedString("System memory pressure is high. Recording may feel slower than usual.", comment: "")
        case .critical:
            title = NSLocalizedString("System memory pressure is critical. Recording and transcription may lag noticeably.", comment: "")
        case .normal:
            return
        }

        NotificationManager.shared.showNotification(
            title: title,
            type: .warning
        )
    }

    private func handlePressureEvent(_ event: DispatchSource.MemoryPressureEvent) {
        let newLevel: Level
        if event.contains(.critical) {
            newLevel = .critical
        } else if event.contains(.warning) {
            newLevel = .warning
        } else {
            newLevel = .normal
        }

        currentLevel = newLevel
    }
}
