import CoreAudio
import Foundation

/// Conservatively quiet whenever any process is capturing audio, including calls.
/// Reads Core Audio state only; Felt never opens or records microphone input.
@MainActor
final class CallMonitor {
    private var timer: Timer?
    var onChange: ((Bool) -> Void)?

    func start() {
        stop()
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer?.tolerance = 0.1
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func poll() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                                mScope: kAudioObjectPropertyScopeGlobal,
                                                mElement: kAudioObjectPropertyElementMain)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else {
            onChange?(false); return
        }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = processes.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(system, &address, 0, nil, &size, $0.baseAddress!)
        }
        guard status == noErr else { onChange?(false); return }
        let active = processes.contains { process in
            var inputAddress = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningInput,
                                                         mScope: kAudioObjectPropertyScopeGlobal,
                                                         mElement: kAudioObjectPropertyElementMain)
            var running: UInt32 = 0
            var bytes = UInt32(MemoryLayout<UInt32>.size)
            return AudioObjectGetPropertyData(process, &inputAddress, 0, nil, &bytes, &running) == noErr && running != 0
        }
        onChange?(active)
    }
}
