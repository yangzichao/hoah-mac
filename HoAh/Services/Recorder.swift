import Foundation
import AVFoundation
import CoreAudio
import os

@MainActor
class Recorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    typealias StreamingChunkHandler = @Sendable (Data) -> Void

    private enum CaptureMode {
        case fileRecording
        case streaming
    }

    private var recorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var streamingContext: StreamingCaptureContext?
    private var currentOutputURL: URL?
    private var currentStreamingChunkHandler: StreamingChunkHandler?
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "Recorder")
    private let deviceManager = AudioDeviceManager.shared
    private var deviceObserver: NSObjectProtocol?
    private var isReconfiguring = false
    private var pendingDeviceChange = false
    private var activeCaptureMode: CaptureMode?
    private let mediaController = MediaController.shared
    @Published var audioMeter = AudioMeter(averagePower: 0, peakPower: 0)
    private var audioLevelCheckTask: Task<Void, Never>?
    private var audioMeterUpdateTask: Task<Void, Never>?
    private var hasDetectedAudioInCurrentSession = false
    private var isStoppingCapture = false
    
    enum RecorderError: Error {
        case couldNotStartRecording
    }
    
    override init() {
        super.init()
        setupDeviceChangeObserver()
    }
    
    private func setupDeviceChangeObserver() {
        deviceObserver = AudioDeviceConfiguration.createDeviceChangeObserver { [weak self] in
            Task {
                await self?.handleDeviceChange()
            }
        }
    }
    
    private func handleDeviceChange() async {
        guard !isReconfiguring else {
            pendingDeviceChange = true
            return
        }
        isReconfiguring = true
        defer { isReconfiguring = false }

        guard recorder != nil || audioEngine != nil else { return }

        let currentURL = currentOutputURL ?? recorder?.url
        let currentMode = activeCaptureMode
        let currentHandler = currentStreamingChunkHandler
        await stopRecording()

        if let url = currentURL {
            do {
                switch currentMode {
                case .streaming:
                    if let currentHandler {
                        try await startStreaming(toOutputFile: url, onChunk: currentHandler)
                    }
                case .fileRecording, .none:
                    try await startRecording(toOutputFile: url)
                }
            } catch {
                logger.error("❌ Failed to restart recording after device change: \(error.localizedDescription)")
            }
        }

        if pendingDeviceChange {
            pendingDeviceChange = false
            await handleDeviceChange()
        }
    }
    
    private func configureAudioSession(with deviceID: AudioDeviceID) async throws {
        try AudioDeviceConfiguration.setDefaultInputDevice(deviceID)
    }
    
    func startRecording(toOutputFile url: URL) async throws {
        deviceManager.isRecordingActive = true
        currentOutputURL = url
        activeCaptureMode = .fileRecording
        
        let currentDeviceID = deviceManager.getCurrentDevice()
        let lastDeviceID = UserDefaults.hoah.string(forKey: "lastUsedMicrophoneDeviceID")
        
        if String(currentDeviceID) != lastDeviceID {
            if let deviceName = deviceManager.availableDevices.first(where: { $0.id == currentDeviceID })?.name {
                await MainActor.run {
                    NotificationManager.shared.showNotification(
                        title: "Using: \(deviceName)",
                        type: .info
                    )
                }
            }
        }
        UserDefaults.hoah.set(String(currentDeviceID), forKey: "lastUsedMicrophoneDeviceID")
        
        hasDetectedAudioInCurrentSession = false

        if currentDeviceID != 0 {
            do {
                try await configureAudioSession(with: currentDeviceID)
            } catch {
                logger.warning("⚠️ Failed to configure audio session for device \(currentDeviceID), attempting to continue: \(error.localizedDescription)")
            }
        }
        
        let recordSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        do {
            recorder = try AVAudioRecorder(url: url, settings: recordSettings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            
            if recorder?.record() == false {
                logger.error("❌ Could not start recording")
                throw RecorderError.couldNotStartRecording
            }
            
            Task { [weak self] in
                guard let self = self else { return }
                _ = await self.mediaController.muteSystemAudio()
            }
            
            audioLevelCheckTask?.cancel()
            audioMeterUpdateTask?.cancel()
            
            audioMeterUpdateTask = Task {
                while recorder != nil && !Task.isCancelled {
                    updateAudioMeter()
                    try? await Task.sleep(nanoseconds: 33_000_000)
                }
            }
            
            audioLevelCheckTask = Task {
                let notificationChecks: [TimeInterval] = [5.0, 12.0]

                for delay in notificationChecks {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    if Task.isCancelled { return }

                    if self.hasDetectedAudioInCurrentSession {
                        return
                    }

                    await MainActor.run {
                        NotificationManager.shared.showNotification(
                            title: "No Audio Detected",
                            type: .warning
                        )
                    }
                }
            }
            
        } catch {
            logger.error("Failed to create audio recorder: \(error.localizedDescription)")
            await stopRecording()
            throw RecorderError.couldNotStartRecording
        }
    }

    func startStreaming(
        toOutputFile url: URL,
        sampleRate: Double = 16_000,
        chunkDurationMs: Int = 100,
        onChunk: @escaping StreamingChunkHandler
    ) async throws {
        deviceManager.isRecordingActive = true
        currentOutputURL = url
        currentStreamingChunkHandler = onChunk
        activeCaptureMode = .streaming

        let currentDeviceID = deviceManager.getCurrentDevice()
        let lastDeviceID = UserDefaults.hoah.string(forKey: "lastUsedMicrophoneDeviceID")

        if String(currentDeviceID) != lastDeviceID {
            if let deviceName = deviceManager.availableDevices.first(where: { $0.id == currentDeviceID })?.name {
                await MainActor.run {
                    NotificationManager.shared.showNotification(
                        title: "Using: \(deviceName)",
                        type: .info
                    )
                }
            }
        }
        UserDefaults.hoah.set(String(currentDeviceID), forKey: "lastUsedMicrophoneDeviceID")

        hasDetectedAudioInCurrentSession = false

        if currentDeviceID != 0 {
            do {
                try await configureAudioSession(with: currentDeviceID)
            } catch {
                logger.warning("⚠️ Failed to configure audio session for device \(currentDeviceID), attempting to continue: \(error.localizedDescription)")
            }
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw RecorderError.couldNotStartRecording
        }

        let chunkSizeInBytes = max(1, Int((Double(chunkDurationMs) / 1000.0) * sampleRate) * 2)

        do {
            let audioFile = try AVAudioFile(
                forWriting: url,
                settings: outputFormat.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )

            let meterUpdate: @Sendable (Double, Double) -> Void = { [weak self] average, peak in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let newAudioMeter = AudioMeter(averagePower: average, peakPower: peak)
                    if !self.hasDetectedAudioInCurrentSession && newAudioMeter.averagePower > 0.01 {
                        self.hasDetectedAudioInCurrentSession = true
                    }
                    self.audioMeter = newAudioMeter
                }
            }

            let context = StreamingCaptureContext(
                inputFormat: inputFormat,
                outputFormat: outputFormat,
                audioFile: audioFile,
                chunkSizeInBytes: chunkSizeInBytes,
                onChunk: onChunk,
                onMeterUpdate: meterUpdate
            )

            streamingContext = context
            audioEngine = engine

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [context] buffer, _ in
                context.process(buffer: buffer)
            }

            try engine.start()

            Task { [weak self] in
                guard let self else { return }
                _ = await self.mediaController.muteSystemAudio()
            }

            audioLevelCheckTask?.cancel()
            audioMeterUpdateTask?.cancel()

            audioLevelCheckTask = Task {
                let notificationChecks: [TimeInterval] = [5.0, 12.0]

                for delay in notificationChecks {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    if Task.isCancelled { return }
                    if self.hasDetectedAudioInCurrentSession { return }

                    await MainActor.run {
                        NotificationManager.shared.showNotification(
                            title: "No Audio Detected",
                            type: .warning
                        )
                    }
                }
            }
        } catch {
            logger.error("Failed to start streaming recorder: \(error.localizedDescription)")
            await stopRecording()
            throw RecorderError.couldNotStartRecording
        }
    }
    
    func stopRecording() async {
        if isStoppingCapture {
            return
        }
        isStoppingCapture = true
        defer {
            deviceManager.isRecordingActive = false
            isStoppingCapture = false
        }

        audioLevelCheckTask?.cancel()
        audioMeterUpdateTask?.cancel()

        let engine = audioEngine
        let context = streamingContext
        let fileRecorder = recorder

        context?.beginShutdown(flushPendingAudio: true)
        engine?.stop()
        // Let Core Audio quiesce the input thread before touching the tap graph.
        try? await Task.sleep(nanoseconds: 50_000_000)
        engine?.inputNode.removeTap(onBus: 0)
        engine?.reset()

        fileRecorder?.stop()
        audioEngine = nil
        streamingContext = nil
        self.recorder = nil
        audioMeter = AudioMeter(averagePower: 0, peakPower: 0)
        currentOutputURL = nil
        currentStreamingChunkHandler = nil
        activeCaptureMode = nil
        hasDetectedAudioInCurrentSession = false
        
        Task {
            await mediaController.unmuteSystemAudio()
        }
    }

    private func updateAudioMeter() {
        guard let recorder = recorder else { return }
        recorder.updateMeters()
        
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        let minVisibleDb: Float = -60.0 
        let maxVisibleDb: Float = 0.0

        let normalizedAverage: Float
        if averagePower < minVisibleDb {
            normalizedAverage = 0.0
        } else if averagePower >= maxVisibleDb {
            normalizedAverage = 1.0
        } else {
            normalizedAverage = (averagePower - minVisibleDb) / (maxVisibleDb - minVisibleDb)
        }
        
        let normalizedPeak: Float
        if peakPower < minVisibleDb {
            normalizedPeak = 0.0
        } else if peakPower >= maxVisibleDb {
            normalizedPeak = 1.0
        } else {
            normalizedPeak = (peakPower - minVisibleDb) / (maxVisibleDb - minVisibleDb)
        }
        
        let newAudioMeter = AudioMeter(averagePower: Double(normalizedAverage), peakPower: Double(normalizedPeak))

        if !hasDetectedAudioInCurrentSession && newAudioMeter.averagePower > 0.01 {
            hasDetectedAudioInCurrentSession = true
        }
        
        audioMeter = newAudioMeter
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            logger.error("❌ Recording finished unsuccessfully - file may be corrupted or empty")
            Task { @MainActor in
                NotificationManager.shared.showNotification(
                    title: "Recording failed - audio file corrupted",
                    type: .error
                )
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            logger.error("❌ Recording encode error during session: \(error.localizedDescription)")
            Task { @MainActor in
                NotificationManager.shared.showNotification(
                    title: "Recording error: \(error.localizedDescription)",
                    type: .error
                )
            }
        }
    }
    
    deinit {
        audioLevelCheckTask?.cancel()
        audioMeterUpdateTask?.cancel()
        if let observer = deviceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

struct AudioMeter: Equatable {
    let averagePower: Double
    let peakPower: Double
}

private final class StreamingCaptureContext {
    private let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter
    private let audioFile: AVAudioFile
    private let chunkSizeInBytes: Int
    private let onChunk: @Sendable (Data) -> Void
    private let onMeterUpdate: @Sendable (Double, Double) -> Void
    private let lock = NSLock()

    private var accumulator = Data()
    private var isShuttingDown = false

    init(
        inputFormat: AVAudioFormat,
        outputFormat: AVAudioFormat,
        audioFile: AVAudioFile,
        chunkSizeInBytes: Int,
        onChunk: @escaping @Sendable (Data) -> Void,
        onMeterUpdate: @escaping @Sendable (Double, Double) -> Void
    ) {
        self.outputFormat = outputFormat
        self.audioFile = audioFile
        self.chunkSizeInBytes = chunkSizeInBytes
        self.onChunk = onChunk
        self.onMeterUpdate = onMeterUpdate
        self.converter = AVAudioConverter(from: inputFormat, to: outputFormat)!
    }

    func process(buffer: AVAudioPCMBuffer) {
        lock.lock()
        let shouldDrop = isShuttingDown
        lock.unlock()

        if shouldDrop {
            return
        }

        let frameRatio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = max(1, AVAudioFrameCount(Double(buffer.frameLength) * frameRatio) + 1)

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            return
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if conversionError != nil {
            return
        }

        guard status == .haveData || status == .inputRanDry,
              convertedBuffer.frameLength > 0,
              let channelData = convertedBuffer.int16ChannelData else {
            return
        }

        do {
            try audioFile.write(from: convertedBuffer)
        } catch {
            return
        }

        let sampleCount = Int(convertedBuffer.frameLength)
        let byteCount = sampleCount * MemoryLayout<Int16>.size
        let data = Data(bytes: channelData[0], count: byteCount)

        updateMeter(using: data)
        enqueue(data)
    }

    func beginShutdown(flushPendingAudio: Bool) {
        lock.lock()
        isShuttingDown = true
        let remaining = accumulator
        accumulator.removeAll(keepingCapacity: false)
        lock.unlock()

        guard flushPendingAudio, !remaining.isEmpty else { return }
        onChunk(remaining)
    }

    func flushPendingAudio() {
        lock.lock()
        let remaining = accumulator
        accumulator.removeAll(keepingCapacity: false)
        lock.unlock()

        guard !remaining.isEmpty else { return }
        onChunk(remaining)
    }

    private func enqueue(_ data: Data) {
        lock.lock()
        accumulator.append(data)

        var chunks: [Data] = []
        while accumulator.count >= chunkSizeInBytes {
            chunks.append(Data(accumulator.prefix(chunkSizeInBytes)))
            accumulator.removeFirst(chunkSizeInBytes)
        }
        lock.unlock()

        for chunk in chunks {
            onChunk(chunk)
        }
    }

    private func updateMeter(using data: Data) {
        let samples = data.withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: Int16.self))
        }

        guard !samples.isEmpty else { return }

        var sumSquares = 0.0
        var peak = 0.0

        for sample in samples {
            let normalized = min(1.0, abs(Double(sample)) / Double(Int16.max))
            sumSquares += normalized * normalized
            peak = max(peak, normalized)
        }

        let rms = sqrt(sumSquares / Double(samples.count))
        onMeterUpdate(rms, peak)
    }
}
