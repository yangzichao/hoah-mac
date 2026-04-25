import Foundation
import CoreAudio
import AVFoundation
import os

struct PrioritizedDevice: Codable, Identifiable {
    let id: String
    let name: String
    let priority: Int
}

enum AudioInputMode: String, CaseIterable {
    case systemDefault = "System Default"
    case custom = "Custom Device"
    case prioritized = "Prioritized"
}

class AudioDeviceManager: ObservableObject {
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AudioDeviceManager")
    private var deviceChangeListener: AudioObjectPropertyListenerBlock?
    private var defaultInputDeviceChangeListener: AudioObjectPropertyListenerBlock?
    @Published var availableDevices: [(id: AudioDeviceID, uid: String, name: String)] = []
    @Published var selectedDeviceID: AudioDeviceID?
    @Published var inputMode: AudioInputMode = .systemDefault
    @Published var prioritizedDevices: [PrioritizedDevice] = []
    @Published private(set) var fallbackDeviceID: AudioDeviceID?
    
    var isRecordingActive: Bool = false
    
    static let shared = AudioDeviceManager()

    init() {
        refreshSystemDefaultInputDevice()
        loadPrioritizedDevices()
        loadAvailableDevices { [weak self] in
            self?.initializeSelectedDevice()
        }
        
        if let savedMode = UserDefaults.hoah.audioInputModeRawValue,
           let mode = AudioInputMode(rawValue: savedMode) {
            inputMode = mode
        }
        
        setupDeviceChangeNotifications()
        setupDefaultInputDeviceChangeNotifications()
    }
    
    func setupFallbackDevice() {
        refreshSystemDefaultInputDevice()
    }

    private func refreshSystemDefaultInputDevice() {
        guard let deviceID = AudioDeviceConfiguration.getDefaultInputDevice(),
              deviceID != 0 else {
            fallbackDeviceID = nil
            logger.warning("No system default input device is currently available")
            return
        }

        fallbackDeviceID = deviceID
        if let name = getDeviceName(deviceID: deviceID) {
            logger.info("System default input device set to: \(name) (ID: \(deviceID))")
        }
    }
    
    private func initializeSelectedDevice() {
        if inputMode == .prioritized {
            selectHighestPriorityAvailableDevice()
            return
        }
        
        if let savedUID = UserDefaults.hoah.selectedAudioDeviceUID {
            if let device = availableDevices.first(where: { $0.uid == savedUID }) {
                selectedDeviceID = device.id
                logger.info("Loaded saved device UID: \(savedUID), mapped to ID: \(device.id)")
                if let name = getDeviceName(deviceID: device.id) {
                    logger.info("Using saved device: \(name)")
                }
            } else {
                logger.warning("Saved device UID \(savedUID) is not currently available")
                fallbackToDefaultDevice()
            }
        } else {
            fallbackToDefaultDevice()
        }
    }
    
    private func isDeviceAvailable(_ deviceID: AudioDeviceID) -> Bool {
        return availableDevices.contains { $0.id == deviceID }
    }

    private func isUsableInputDevice(_ deviceID: AudioDeviceID) -> Bool {
        return isDeviceAvailable(deviceID) && hasInputChannels(deviceID: deviceID)
    }
    
    private func fallbackToDefaultDevice() {
        logger.info("Temporarily falling back to system default input device – user preference remains intact.")

        if let currentID = selectedDeviceID, !isDeviceAvailable(currentID) {
            selectedDeviceID = nil
        }

        notifyDeviceChange()
    }
    
    func loadAvailableDevices(completion: (() -> Void)? = nil) {
        logger.info("Loading available audio devices...")
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var result = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize
        )
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        logger.info("Found \(deviceCount) total audio devices")
        
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        if result != noErr {
            logger.error("Error getting audio devices: \(result)")
            return
        }
        
        let devices = deviceIDs.compactMap { deviceID -> (id: AudioDeviceID, uid: String, name: String)? in
            guard let name = getDeviceName(deviceID: deviceID),
                  let uid = getDeviceUID(deviceID: deviceID),
                  isValidInputDevice(deviceID: deviceID) else {
                return nil
            }
            return (id: deviceID, uid: uid, name: name)
        }
        
        logger.info("Found \(devices.count) input devices")
        devices.forEach { device in
            logger.info("Available device: \(device.name) (ID: \(device.id))")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.availableDevices = devices.map { ($0.id, $0.uid, $0.name) }
            self.refreshSystemDefaultInputDevice()
            _ = self.restoreSavedCustomDeviceIfAvailable()
            if let currentID = self.selectedDeviceID, !devices.contains(where: { $0.id == currentID }) {
                self.logger.warning("Currently selected device is no longer available")
                self.fallbackToDefaultDevice()
            }
            completion?()
        }
    }
    
    func getDeviceName(deviceID: AudioDeviceID) -> String? {
        return getDeviceStringProperty(
            deviceID: deviceID,
            selector: kAudioDevicePropertyDeviceNameCFString
        )
    }
    
    private func isValidInputDevice(deviceID: AudioDeviceID) -> Bool {
        guard hasInputChannels(deviceID: deviceID, logFailures: true) else {
            return false
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &transportType
        )

        if status != noErr {
            logger.warning("Could not get transport type for device \(deviceID), including it anyway")
            return true
        }

        let isVirtual = transportType == kAudioDeviceTransportTypeVirtual
        let isAggregate = transportType == kAudioDeviceTransportTypeAggregate

        return !isVirtual && !isAggregate
    }

    private func hasInputChannels(deviceID: AudioDeviceID, logFailures: Bool = false) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize: UInt32 = 0
        var result = AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &propertySize
        )

        if result != noErr {
            if logFailures {
                logger.error("Error checking input capability for device \(deviceID): \(result)")
            }
            return false
        }

        guard propertySize > 0 else {
            return false
        }

        let rawBufferList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(propertySize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawBufferList.deallocate() }

        let bufferList = rawBufferList.bindMemory(to: AudioBufferList.self, capacity: 1)

        result = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            bufferList
        )

        if result != noErr {
            if logFailures {
                logger.error("Error getting stream configuration for device \(deviceID): \(result)")
            }
            return false
        }

        let inputChannelCount = UnsafeMutableAudioBufferListPointer(bufferList)
            .reduce(0) { total, audioBuffer in
                total + Int(audioBuffer.mNumberChannels)
            }

        return inputChannelCount > 0
    }

    func selectDevice(id: AudioDeviceID) {
        logger.info("Selecting device with ID: \(id)")
        if let name = getDeviceName(deviceID: id) {
            logger.info("Selected device name: \(name)")
        }

        if let deviceToSelect = availableDevices.first(where: { $0.id == id }) {
            let uid = deviceToSelect.uid
            DispatchQueue.main.async {
                self.selectedDeviceID = id
                UserDefaults.hoah.selectedAudioDeviceUID = uid
                self.logger.info("Device selection saved with UID: \(uid)")
                self.notifyDeviceChange()
            }
        } else {
            logger.error("Attempted to select unavailable device: \(id)")
            fallbackToDefaultDevice()
        }
    }

    func selectDeviceAndSwitchToCustomMode(id: AudioDeviceID) {
        if let deviceToSelect = availableDevices.first(where: { $0.id == id }) {
            let uid = deviceToSelect.uid
            DispatchQueue.main.async {
                self.inputMode = .custom
                self.selectedDeviceID = id
                UserDefaults.hoah.audioInputModeRawValue = AudioInputMode.custom.rawValue
                UserDefaults.hoah.selectedAudioDeviceUID = uid
                self.notifyDeviceChange()
            }
        } else {
            logger.error("Attempted to select unavailable device: \(id)")
            fallbackToDefaultDevice()
        }
    }
    
    func selectInputMode(_ mode: AudioInputMode) {
        inputMode = mode
        UserDefaults.hoah.audioInputModeRawValue = mode.rawValue
        
        if mode == .systemDefault {
            selectedDeviceID = nil
            UserDefaults.hoah.removeObject(forKey: UserDefaults.Keys.selectedAudioDeviceUID)
        } else if selectedDeviceID == nil {
            if inputMode == .custom {
                if let firstDevice = availableDevices.first {
                    selectDevice(id: firstDevice.id)
                }
            } else if inputMode == .prioritized {
                selectHighestPriorityAvailableDevice()
            }
        }
        
        notifyDeviceChange()
    }
    
    func getCurrentDevice() -> AudioDeviceID {
        switch inputMode {
        case .systemDefault:
            return resolveSystemDefaultInputDevice() ?? 0
        case .custom:
            if let id = selectedDeviceID, isUsableInputDevice(id) {
                return id
            } else {
                return resolveSystemDefaultInputDevice() ?? 0
            }
        case .prioritized:
            let sortedDevices = prioritizedDevices.sorted { $0.priority < $1.priority }
            for device in sortedDevices {
                if let available = availableDevices.first(where: { $0.uid == device.id }),
                   isUsableInputDevice(available.id) {
                    return available.id
                }
            }
            return resolveSystemDefaultInputDevice() ?? 0
        }
    }

    private func resolveSystemDefaultInputDevice() -> AudioDeviceID? {
        if let deviceID = AudioDeviceConfiguration.getDefaultInputDevice(),
           deviceID != 0,
           hasInputChannels(deviceID: deviceID) {
            return deviceID
        }

        if let deviceID = fallbackDeviceID,
           deviceID != 0,
           hasInputChannels(deviceID: deviceID) {
            return deviceID
        }

        return availableDevices.first(where: { hasInputChannels(deviceID: $0.id) })?.id
    }

    private func restoreSavedCustomDeviceIfAvailable() -> Bool {
        guard inputMode == .custom,
              let savedUID = UserDefaults.hoah.selectedAudioDeviceUID,
              let savedDevice = availableDevices.first(where: { $0.uid == savedUID })
        else {
            return false
        }

        guard selectedDeviceID != savedDevice.id else {
            return false
        }

        selectedDeviceID = savedDevice.id
        logger.info("Restored saved input device UID: \(savedUID), mapped to ID: \(savedDevice.id)")
        notifyDeviceChange()
        return true
    }
    
    private func loadPrioritizedDevices() {
        if let data = UserDefaults.hoah.prioritizedDevicesData,
           let devices = try? JSONDecoder().decode([PrioritizedDevice].self, from: data) {
            prioritizedDevices = devices
            logger.info("Loaded \(devices.count) prioritized devices")
        }
    }
    
    func savePrioritizedDevices() {
        if let data = try? JSONEncoder().encode(prioritizedDevices) {
            UserDefaults.hoah.prioritizedDevicesData = data
            logger.info("Saved \(self.prioritizedDevices.count) prioritized devices")
        }
    }
    
    func addPrioritizedDevice(uid: String, name: String) {
        guard !prioritizedDevices.contains(where: { $0.id == uid }) else { return }
        let nextPriority = (prioritizedDevices.map { $0.priority }.max() ?? -1) + 1
        let device = PrioritizedDevice(id: uid, name: name, priority: nextPriority)
        prioritizedDevices.append(device)
        savePrioritizedDevices()
    }
    
    func removePrioritizedDevice(id: String) {
        let wasSelected = selectedDeviceID == availableDevices.first(where: { $0.uid == id })?.id
        prioritizedDevices.removeAll { $0.id == id }
        
        let updatedDevices = prioritizedDevices.enumerated().map { index, device in
            PrioritizedDevice(id: device.id, name: device.name, priority: index)
        }
        
        prioritizedDevices = updatedDevices
        savePrioritizedDevices()
        
        if wasSelected && inputMode == .prioritized {
            selectHighestPriorityAvailableDevice()
        }
    }
    
    func updatePriorities(devices: [PrioritizedDevice]) {
        prioritizedDevices = devices
        savePrioritizedDevices()
        
        if inputMode == .prioritized {
            selectHighestPriorityAvailableDevice()
        }
        
        notifyDeviceChange()
    }
    
    private func selectHighestPriorityAvailableDevice() {
        let sortedDevices = prioritizedDevices.sorted { $0.priority < $1.priority }
        
        for device in sortedDevices {
            if let availableDevice = availableDevices.first(where: { $0.uid == device.id }) {
                selectedDeviceID = availableDevice.id
                logger.info("Selected prioritized device: \(device.name) (Priority: \(device.priority))")
                
                do {
                    try AudioDeviceConfiguration.setDefaultInputDevice(availableDevice.id)
                } catch {
                    logger.error("Failed to set prioritized device: \(error.localizedDescription)")
                    continue
                }
                notifyDeviceChange()
                return
            }
        }
        
        fallbackToDefaultDevice()
    }
    
    private func setupDeviceChangeNotifications() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.handleDeviceListChange()
        }
        deviceChangeListener = listener

        let status = AudioObjectAddPropertyListenerBlock(
            systemObjectID,
            &address,
            DispatchQueue.main,
            listener
        )

        if status != noErr {
            logger.error("Failed to add device change listener: \(status)")
        } else {
            logger.info("Successfully added device change listener")
        }
    }

    private func setupDefaultInputDeviceChangeNotifications() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.handleDefaultInputDeviceChange()
        }
        defaultInputDeviceChangeListener = listener

        let status = AudioObjectAddPropertyListenerBlock(
            systemObjectID,
            &address,
            DispatchQueue.main,
            listener
        )

        if status != noErr {
            logger.error("Failed to add default input device listener: \(status)")
        } else {
            logger.info("Successfully added default input device listener")
        }
    }
    
    private func handleDeviceListChange() {
        logger.info("Device list change detected")
        loadAvailableDevices { [weak self] in
            guard let self = self else { return }
            
            if self.inputMode == .prioritized {
                self.selectHighestPriorityAvailableDevice()
            } else if self.inputMode == .custom,
                      let currentID = self.selectedDeviceID,
                      !self.isDeviceAvailable(currentID) {
                self.fallbackToDefaultDevice()
            }
        }
    }

    private func handleDefaultInputDeviceChange() {
        logger.info("Default input device change detected")
        refreshSystemDefaultInputDevice()
        notifyDeviceChange()
    }
    
    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        return getDeviceStringProperty(
            deviceID: deviceID,
            selector: kAudioDevicePropertyDeviceUID
        )
    }
    
    deinit {
        if let listener = deviceChangeListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                listener
            )
        }

        if let listener = defaultInputDeviceChangeListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                listener
            )
        }
    }
    
    private func createPropertyAddress(selector: AudioObjectPropertySelector,
                                    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                                    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        return AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
    }
    
    private func getDeviceStringProperty(
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> String? {
        guard deviceID != 0 else { return nil }
        
        var address = createPropertyAddress(selector: selector, scope: scope)
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var property = "" as CFString
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &property
        )
        
        if status != noErr {
            logger.error("Failed to get device property \(selector) for device \(deviceID): \(status)")
            return nil
        }
        
        return property as String
    }
    
    private func notifyDeviceChange() {
        if !isRecordingActive {
            NotificationCenter.default.post(name: NSNotification.Name("AudioDeviceChanged"), object: nil)
        }
    }
} 
