import CoreAudio
import DuoBarCore
import Foundation

enum AudioDeviceSystemProperty: CaseIterable, Hashable {
    case devices
    case defaultOutput
    case defaultInput

    var selector: AudioObjectPropertySelector {
        switch self {
        case .devices: kAudioHardwarePropertyDevices
        case .defaultOutput: kAudioHardwarePropertyDefaultOutputDevice
        case .defaultInput: kAudioHardwarePropertyDefaultInputDevice
        }
    }
}

final class AudioDeviceObservation {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        let action = cancellation
        cancellation = nil
        action?()
    }

    deinit {
        cancellation?()
    }
}

protocol AudioDeviceBackend: AnyObject {
    func devices() -> [AudioDeviceDescriptor]
    func defaultDevice(direction: AudioDeviceDirection) -> AudioDeviceID?
    func setDefaultDevice(_ deviceID: AudioDeviceID, direction: AudioDeviceDirection) -> OSStatus
    func inputVolumeChannels(deviceID: AudioDeviceID) -> [AudioObjectPropertyElement]
    func inputVolume(deviceID: AudioDeviceID, channel: AudioObjectPropertyElement) -> Float32?
    func inputVolumeIsSettable(deviceID: AudioDeviceID, channel: AudioObjectPropertyElement) -> Bool
    func setInputVolume(_ value: Float32, deviceID: AudioDeviceID, channel: AudioObjectPropertyElement) -> OSStatus
    func observeSystem(_ property: AudioDeviceSystemProperty, handler: @escaping @MainActor () -> Void) -> AudioDeviceObservation?
    func observeInputVolume(deviceID: AudioDeviceID, channel: AudioObjectPropertyElement, handler: @escaping @MainActor () -> Void) -> AudioDeviceObservation?
}

final class CoreAudioDeviceBackend: AudioDeviceBackend {
    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let listenerQueue = DispatchQueue(label: "com.mikeli.duobar.audio-device-switcher")

    func devices() -> [AudioDeviceDescriptor] {
        readDeviceIDs().compactMap(describe)
    }

    func defaultDevice(direction: AudioDeviceDirection) -> AudioDeviceID? {
        var address = globalAddress(direction == .output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice)
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(Self.systemObject, &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    func setDefaultDevice(_ deviceID: AudioDeviceID, direction: AudioDeviceDirection) -> OSStatus {
        var address = globalAddress(direction == .output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice)
        var deviceID = deviceID
        return AudioObjectSetPropertyData(Self.systemObject, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID)
    }

    func inputVolumeChannels(deviceID: AudioDeviceID) -> [AudioObjectPropertyElement] {
        if hasProperty(deviceID: deviceID, address: inputVolumeAddress(channel: kAudioObjectPropertyElementMain)) {
            return [kAudioObjectPropertyElementMain]
        }
        let channelCount = inputChannelCount(deviceID: deviceID) ?? 2
        guard channelCount > 0 else { return [] }
        return Array(AudioObjectPropertyElement(1)...channelCount).filter {
            hasProperty(deviceID: deviceID, address: inputVolumeAddress(channel: $0))
        }
    }

    func inputVolume(deviceID: AudioDeviceID, channel: AudioObjectPropertyElement) -> Float32? {
        var address = inputVolumeAddress(channel: channel)
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    func inputVolumeIsSettable(deviceID: AudioDeviceID, channel: AudioObjectPropertyElement) -> Bool {
        var address = inputVolumeAddress(channel: channel)
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr && settable.boolValue
    }

    func setInputVolume(_ value: Float32, deviceID: AudioDeviceID, channel: AudioObjectPropertyElement) -> OSStatus {
        var address = inputVolumeAddress(channel: channel)
        var value = value
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    }

    func observeSystem(_ property: AudioDeviceSystemProperty, handler: @escaping @MainActor () -> Void) -> AudioDeviceObservation? {
        observe(objectID: Self.systemObject, address: globalAddress(property.selector), handler: handler)
    }

    func observeInputVolume(deviceID: AudioDeviceID, channel: AudioObjectPropertyElement, handler: @escaping @MainActor () -> Void) -> AudioDeviceObservation? {
        observe(objectID: deviceID, address: inputVolumeAddress(channel: channel), handler: handler)
    }

    private func observe(objectID: AudioObjectID, address: AudioObjectPropertyAddress, handler: @escaping @MainActor () -> Void) -> AudioDeviceObservation? {
        let queue = listenerQueue
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            DispatchQueue.main.async { handler() }
        }
        var address = address
        guard AudioObjectAddPropertyListenerBlock(objectID, &address, queue, block) == noErr else { return nil }
        let registeredAddress = address
        return AudioDeviceObservation {
            var address = registeredAddress
            AudioObjectRemovePropertyListenerBlock(objectID, &address, queue, block)
        }
    }

    private func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private func inputVolumeAddress(channel: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeInput, mElement: channel)
    }

    private func hasProperty(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        return AudioObjectHasProperty(deviceID, &address)
    }

    private func inputChannelCount(deviceID: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr,
              size >= MemoryLayout<AudioBufferList>.size else { return nil }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, buffer) == noErr else { return nil }
        return UnsafeMutableAudioBufferListPointer(buffer.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + $1.mNumberChannels }
    }

    private func readDeviceIDs() -> [AudioDeviceID] {
        var address = globalAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(Self.systemObject, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: kAudioObjectUnknown, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(Self.systemObject, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private func describe(_ deviceID: AudioDeviceID) -> AudioDeviceDescriptor? {
        var address = globalAddress(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr,
              let name = name?.takeRetainedValue() as String? else { return nil }
        return AudioDeviceDescriptor(id: deviceID, name: name, hasOutput: hasStreams(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput), hasInput: hasStreams(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput))
    }

    private func hasStreams(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr && size > 0
    }
}
