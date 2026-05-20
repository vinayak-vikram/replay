//
//  AudioEngine.swift
//  replay
//
//  Created by Vinayak Vikram on 5/20/26.
//

import AVFoundation
import Combine

enum RecordState {
    case idle, recording, playing
}

@MainActor
final class AudioEngine: ObservableObject {
    @Published var state = RecordState.idle
    @Published var inputLevel: Float = 0
    @Published var permissionGranted = false
    @Published var errorMessage: String?

    private(set) var lastRecordingURL: URL?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    // Accessed from audio tap thread; set only while tap is not running.
    nonisolated(unsafe) private var writingFile: AVAudioFile?

    init() {
        engine.attach(player)
    }

    func requestPermission() async {
        #if os(iOS) || os(visionOS)
        permissionGranted = await AVAudioApplication.requestRecordPermission()
        #elseif os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            permissionGranted = await AVCaptureDevice.requestAccess(for: .audio)
        default:
            permissionGranted = false
        }
        #endif
    }

    func startRecording() {
        guard state == .idle else { return }
        do {
            try configureSession(forPlayback: false)

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            let url = newTempURL()
            writingFile = try AVAudioFile(forWriting: url, settings: format.settings)
            lastRecordingURL = url

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buf, _ in
                guard let self else { return }
                try? self.writingFile?.write(from: buf)
                let level = Self.rmsLevel(buf)
                Task { @MainActor [weak self] in
                    self?.inputLevel = level
                }
            }

            try engine.start()
            state = .recording
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        engine.inputNode.removeTap(onBus: 0)
        writingFile = nil
        engine.stop()
        inputLevel = 0
        state = .idle
    }

    func startPlayback(url: URL? = nil) {
        guard state == .idle else { return }
        guard let target = url ?? lastRecordingURL else { return }
        do {
            try configureSession(forPlayback: true)
            let file = try AVAudioFile(forReading: target)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            try engine.start()
            state = .playing
            player.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.state == .playing else { return }
                    self.player.stop()
                    self.engine.stop()
                    self.state = .idle
                }
            }
            player.play()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopPlayback() {
        guard state == .playing else { return }
        player.stop()
        engine.stop()
        state = .idle
    }

    private func configureSession(forPlayback: Bool) throws {
        #if os(iOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        if forPlayback {
            try session.setCategory(.playback)
        } else {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        }
        try session.setActive(true)
        #endif
    }

    private func newTempURL() -> URL {
        URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
    }

    private static func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let frames = Int(buffer.frameLength)
        let ptr = data[0]
        var sum: Float = 0
        for i in 0..<frames { sum += ptr[i] * ptr[i] }
        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(max(rms, 1e-7))
        // Map -60 dB..0 dB → 0..1
        return max(0, min(1, (db + 60) / 60))
    }
}
