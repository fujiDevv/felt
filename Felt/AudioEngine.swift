import AVFoundation
import CoreAudio
import AudioToolbox
import OSLog

@MainActor
final class FeltAudioEngine {
    private let engine = AVAudioEngine()
    private var players: [GestureID: AVAudioPlayerNode] = [:]
    private var buffers: [SoundWorld: [GestureID: [AVAudioPCMBuffer]]] = [:]
    private var observer: NSObjectProtocol?
    private var previewPlayer: AVAudioPlayer?
    private var previewTask: Task<Void, Never>?
    private var sampleURLs: [SoundWorld: [GestureID: [URL]]] = [:]
    var previewTime: TimeInterval { previewPlayer?.currentTime ?? 0 }
    var previewPeak: Float { previewPlayer?.updateMeters(); return previewPlayer?.peakPower(forChannel: 0) ?? -160 }
    private let log = Logger(subsystem: "com.fujidevv.Felt", category: "Audio")
    private(set) var playbackCompletions = 0
    var onPlayback: ((String) -> Void)?
    var outputDescription: String {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        if let unit = engine.outputNode.audioUnit {
            _ = AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, &size)
        }
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let result = withUnsafeMutablePointer(to: &name) { AudioObjectGetPropertyData(device, &address, 0, nil, &size, $0) }
        let label = result == noErr ? (name?.takeRetainedValue() as String? ?? "Unknown output") : "Output unavailable"
        let format = engine.outputNode.outputFormat(forBus: 0)
        return "\(label) · \(Int(format.sampleRate)) Hz · \(format.channelCount) channels"
    }
    var onError: ((String?) -> Void)?
    var sampleCount: Int { buffers.values.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } } }

    init(offline: Bool = false) {
        for world in SoundWorld.allCases {
            for gesture in GestureID.allCases {
                for variation in 1...3 {
                    let name = "\(world.rawValue)-\(gesture.rawValue)-\(variation)"
                    guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds")
                        ?? Bundle.main.url(forResource: name, withExtension: "wav") else {
                        log.error("Missing sample: \(name, privacy: .public)")
                        continue
                    }
                    do {
                        let file = try AVAudioFile(forReading: url)
                        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                           frameCapacity: AVAudioFrameCount(file.length)) else { continue }
                        try file.read(into: buffer)
                        buffers[world, default: [:]][gesture, default: []].append(buffer)
                        sampleURLs[world, default: [:]][gesture, default: []].append(url)
                    } catch { log.error("Sample decode failed: \(error.localizedDescription, privacy: .public)") }
                }
            }
        }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        for gesture in GestureID.allCases {
            let player = AVAudioPlayerNode()
            players[gesture] = player
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        if offline {
            do { try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096) }
            catch { log.error("Manual rendering setup: \(error.localizedDescription, privacy: .public)") }
        }
        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
                                                          object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.restart()
            }
        }
    }

    func start() {
        guard !engine.isRunning else { return }
        do { engine.prepare(); try engine.start(); onError?(nil) }
        catch { onError?("Audio unavailable. Check your output device."); log.error("Audio start: \(error.localizedDescription, privacy: .public)") }
    }

    func restart() {
        players.values.forEach { $0.stop() }
        engine.stop()
        start()
    }

    func play(_ gesture: GestureID, world: SoundWorld, volume: Double, pan: Float) -> Bool {
        guard let buffer = buffers[world]?[gesture]?.randomElement(), let player = players[gesture] else { return false }
        start()
        guard engine.isRunning else { return false }
        engine.mainMixerNode.outputVolume = Float(max(0, min(1, volume)))
        player.pan = pan
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.playbackCompletions += 1
                self.onPlayback?("Playback finished · \(self.outputDescription)")
            }
        }
        if !player.isPlaying { player.play() }
        return true
    }

    /// Explicit previews use a separate system player so a stalled gesture graph cannot silence the audition.
    func preview(world: SoundWorld, volume: Double) -> Bool {
        previewTask?.cancel()
        previewPlayer?.stop()
        guard let url = sampleURLs[world]?[.pinchOut]?.randomElement() else {
            onError?("Preview sample is missing."); return false
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = Float(max(0, min(1, volume)))
            player.isMeteringEnabled = true
            guard player.prepareToPlay(), player.play() else {
                onError?("Preview could not start. Check your output device."); return false
            }
            previewPlayer = player
            onError?(nil)
            previewTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled, let self else { return }
                player.updateMeters()
                self.onPlayback?("Preview player: \(Int(player.currentTime * 1000)) ms · \(Int(player.peakPower(forChannel: 0))) dBFS")
            }
            return true
        } catch {
            onError?("Preview failed: \(error.localizedDescription)"); return false
        }
    }

    func playDiagnosticTone(volume: Double) {
        previewTask?.cancel(); previewPlayer?.stop()
        let sampleRate = 44100
        let frames = Int(Double(sampleRate) * 0.14)
        var data = Data()
        func word(_ value: UInt16) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
        func dword(_ value: UInt32) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
        data.append(contentsOf: "RIFF".utf8); dword(UInt32(36 + frames * 4))
        data.append(contentsOf: "WAVEfmt ".utf8); dword(16); word(1); word(2)
        dword(UInt32(sampleRate)); dword(UInt32(sampleRate * 4)); word(4); word(16)
        data.append(contentsOf: "data".utf8); dword(UInt32(frames * 4))
        for frame in 0..<frames {
            let fade = min(1, Double(frame) / 441, Double(frames - frame - 1) / 441)
            let sample = Int16(sin(2 * .pi * 440 * Double(frame) / Double(sampleRate)) * 0.25 * fade * 32767)
            word(UInt16(bitPattern: sample)); word(UInt16(bitPattern: sample))
        }
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = Float(max(0, min(1, volume)))
            player.isMeteringEnabled = true
            guard player.prepareToPlay(), player.play() else { onError?("Diagnostic tone could not start"); return }
            previewPlayer = player
            onError?(nil)
            previewTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                player.updateMeters()
                self?.onPlayback?("Test tone: \(Int(player.currentTime * 1000)) ms · \(Int(player.peakPower(forChannel: 0))) dBFS")
            }
        } catch { onError?("Diagnostic tone failed: \(error.localizedDescription)") }
    }

    func renderedPeakForTesting(frames: AVAudioFrameCount = 22050) throws -> Float {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096) else { return 0 }
        var remaining = frames
        var peak: Float = 0
        while remaining > 0 {
            let count = min(remaining, buffer.frameCapacity)
            let status = try engine.renderOffline(count, to: buffer)
            guard status == .success else { break }
            if let channels = buffer.floatChannelData {
                for channel in 0..<Int(buffer.format.channelCount) {
                    for frame in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channels[channel][frame])) }
                }
            }
            remaining -= count
        }
        return peak
    }

    func stop() {
        previewTask?.cancel(); previewTask = nil
        previewPlayer?.stop(); previewPlayer = nil
        players.values.forEach { $0.stop() }
        engine.stop()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}
