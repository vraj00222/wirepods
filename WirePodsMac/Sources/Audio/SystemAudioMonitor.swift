import Foundation
import CoreAudio

/// Polls CoreAudio to detect if the default output device is currently playing audio.
/// When activity is detected for >1.5s, it auto-claims Mac focus so the iPhone can duck automatically.
/// No manual "Active: Mac" tap needed after same-WiFi pairing.

final class SystemAudioMonitor {
    private var timer: Timer?
    private var wasActive = false
    var onMacBecameActive: (() -> Void)?
    var onMacBecameIdle: (() -> Void)?

    func start(interval: TimeInterval = 0.3) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.check()
        }
        timer?.tolerance = 0.05
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        let active = Self.isSystemAudioActive()
        if active && !wasActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                if Self.isSystemAudioActive() {
                    self?.onMacBecameActive?()
                }
            }
        } else if !active && wasActive {
            onMacBecameIdle?()
        }
        wasActive = active
    }

    static func isSystemAudioActive() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID) == noErr else {
            return false
        }
        // Check if device is running somewhere (is actually producing I/O)
        var isRunning: UInt32 = 0
        var runSize = UInt32(MemoryLayout<UInt32>.size)
        var runAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &runAddr, 0, nil, &runSize, &isRunning)
        return status == noErr && isRunning != 0
    }
}
