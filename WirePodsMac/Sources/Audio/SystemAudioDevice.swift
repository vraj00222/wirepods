import Foundation
import CoreAudio

enum SystemAudioDevice {

    static func currentOutputName() -> String? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr else { return nil }

        // Get device name
        var name: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let nameStatus = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)
        guard nameStatus == noErr, let cfName = name?.takeUnretainedValue() else { return nil }
        return cfName as String
    }

    static func isWiredHeadphonesActive() -> Bool {
        guard let name = currentOutputName()?.lowercased() else { return false }
        // Heuristics: "external headphones", "headphones", "usb audio" etc.
        return name.contains("headphone") || name.contains("external") || name.contains("usb")
    }
}
