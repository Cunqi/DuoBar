import CoreAudio
import DuoBarCore
import Foundation

enum AudioDeviceControlFeedback: Equatable {
    case switchFailed
    case switchUnconfirmed
    case inputVolumeFailed
    case inputVolumeUnconfirmed
    case inputVolumeUnavailable

    var message: String {
        switch self {
        case .switchFailed: localized("Device change failed")
        case .switchUnconfirmed: localized("Device change not confirmed")
        case .inputVolumeFailed: localized("Input volume change failed")
        case .inputVolumeUnconfirmed: localized("Input volume not confirmed")
        case .inputVolumeUnavailable: localized("Input volume unavailable")
        }
    }
}

@MainActor
final class AudioDeviceSwitcher: ObservableObject {
    @Published private(set) var outputs: [AudioDeviceOption] = []
    @Published private(set) var inputs: [AudioDeviceOption] = []
    @Published private(set) var inputVolume: Double?
    @Published private(set) var isInputVolumeSettable = false
    @Published private(set) var outputSwitchFeedback: AudioDeviceControlFeedback?
    @Published private(set) var inputSwitchFeedback: AudioDeviceControlFeedback?
    @Published private(set) var inputVolumeFeedback: AudioDeviceControlFeedback?

    private struct ObservationBinding {
        let id: UUID
        let observation: AudioDeviceObservation
    }

    private struct InputVolumeRequest {
        let deviceID: AudioDeviceID
        let channels: Set<AudioObjectPropertyElement>
        let value: Float32
        let writeFailed: Bool
        let notificationBoundary: UInt64
        let previousValues: [AudioObjectPropertyElement: Float32]
    }

    private let backend: any AudioDeviceBackend
    private var systemObservations: [AudioDeviceSystemProperty: ObservationBinding] = [:]
    private var inputObservations: [AudioObjectPropertyElement: ObservationBinding] = [:]
    private var observedInputDeviceID: AudioDeviceID?
    private var requestedOutputDeviceID: AudioDeviceID?
    private var requestedInputDeviceID: AudioDeviceID?
    private var inputVolumeRequest: InputVolumeRequest?
    private var isStarted = false
    private var prefersInputVolumeFeedback = false
    private var inputVolumeWriteIsInProgress = false
    private var inputVolumeNotificationDuringWrite: UInt64?

    init(backend: any AudioDeviceBackend = CoreAudioDeviceBackend()) {
        self.backend = backend
    }

    var defaultInput: AudioDeviceOption? {
        inputs.first(where: \.isDefault)
    }

    var inputFeedback: AudioDeviceControlFeedback? {
        prefersInputVolumeFeedback ? inputVolumeFeedback ?? inputSwitchFeedback : inputSwitchFeedback ?? inputVolumeFeedback
    }

    func start() {
        isStarted = true
        for property in AudioDeviceSystemProperty.allCases where systemObservations[property] == nil {
            let bindingID = UUID()
            if let observation = backend.observeSystem(property, handler: { [weak self] _ in
                guard let self, self.isStarted, self.systemObservations[property]?.id == bindingID else { return }
                self.refresh(
                    confirmOutput: property == .defaultOutput,
                    confirmInput: property == .defaultInput
                )
            }) {
                systemObservations[property] = ObservationBinding(id: bindingID, observation: observation)
            }
        }
        refresh(confirmOutput: true, confirmInput: true)
    }

    func stop() {
        isStarted = false
        requestedOutputDeviceID = nil
        requestedInputDeviceID = nil
        inputVolumeRequest = nil
        outputSwitchFeedback = nil
        inputSwitchFeedback = nil
        inputVolumeFeedback = nil
        inputVolumeWriteIsInProgress = false
        inputVolumeNotificationDuringWrite = nil
        for binding in systemObservations.values {
            binding.observation.cancel()
        }
        systemObservations.removeAll()
        removeInputObservations()
    }

    func setDefault(_ option: AudioDeviceOption, direction: AudioDeviceDirection) {
        let alreadySelected = backend.defaultDevice(direction: direction) == option.id
        if direction == .output {
            requestedOutputDeviceID = alreadySelected ? nil : option.id
            outputSwitchFeedback = nil
        } else {
            prefersInputVolumeFeedback = false
            requestedInputDeviceID = alreadySelected ? nil : option.id
            inputSwitchFeedback = nil
        }
        guard !alreadySelected else {
            refresh()
            return
        }

        let result = backend.setDefaultDevice(option.id, direction: direction)
        let feedback: AudioDeviceControlFeedback = result == noErr ? .switchUnconfirmed : .switchFailed
        if direction == .output {
            outputSwitchFeedback = feedback
        } else {
            inputSwitchFeedback = feedback
        }
        refresh()
    }

    func setInputVolume(_ level: Double) {
        prefersInputVolumeFeedback = true
        guard let deviceID = backend.defaultDevice(direction: .input) else {
            inputVolumeRequest = nil
            inputVolumeFeedback = .inputVolumeUnavailable
            refresh()
            return
        }
        let channels = Array(Set(backend.inputVolumeChannels(deviceID: deviceID))).sorted()
        guard level.isFinite, !channels.isEmpty,
              channels.allSatisfy({ backend.inputVolumeIsSettable(deviceID: deviceID, channel: $0) }) else {
            inputVolumeRequest = nil
            inputVolumeFeedback = .inputVolumeUnavailable
            refresh()
            return
        }

        let scalar = Float32(min(max(level, 0), 1))
        bindInputObservations(deviceID: deviceID, channels: Set(channels))
        let notificationBoundary = backend.notificationBoundary()
        let previousValues = Dictionary(uniqueKeysWithValues: channels.compactMap { channel -> (AudioObjectPropertyElement, Float32)? in
            guard let value = backend.inputVolume(deviceID: deviceID, channel: channel),
                  value.isFinite, (0...1).contains(value) else { return nil }
            return (channel, value)
        })
        inputVolumeRequest = InputVolumeRequest(deviceID: deviceID, channels: Set(channels), value: scalar, writeFailed: false, notificationBoundary: notificationBoundary, previousValues: previousValues)
        inputVolumeFeedback = .inputVolumeUnconfirmed
        inputVolumeWriteIsInProgress = true
        inputVolumeNotificationDuringWrite = nil
        var writeFailed = false
        for channel in channels {
            if backend.setInputVolume(scalar, deviceID: deviceID, channel: channel) != noErr {
                writeFailed = true
            }
        }
        inputVolumeWriteIsInProgress = false
        inputVolumeRequest = InputVolumeRequest(deviceID: deviceID, channels: Set(channels), value: scalar, writeFailed: writeFailed, notificationBoundary: notificationBoundary, previousValues: previousValues)
        inputVolumeFeedback = writeFailed ? .inputVolumeFailed : .inputVolumeUnconfirmed
        refresh(volumeNotification: inputVolumeNotificationDuringWrite)
    }

    private func refresh(confirmOutput: Bool = false, confirmInput: Bool = false, volumeNotification: UInt64? = nil) {
        let descriptors = backend.devices()
        let outputDeviceID = backend.defaultDevice(direction: .output)
        let inputDeviceID = backend.defaultDevice(direction: .input)
        outputs = AudioDeviceOption.options(from: descriptors, direction: .output, defaultID: outputDeviceID)
        inputs = AudioDeviceOption.options(from: descriptors, direction: .input, defaultID: inputDeviceID)
        if confirmOutput, let requestedOutputDeviceID, outputDeviceID == requestedOutputDeviceID {
            self.requestedOutputDeviceID = nil
            outputSwitchFeedback = nil
        }
        if confirmInput, let requestedInputDeviceID, inputDeviceID == requestedInputDeviceID {
            self.requestedInputDeviceID = nil
            inputSwitchFeedback = nil
        }
        refreshInputVolume(deviceID: inputDeviceID, notificationSequence: volumeNotification)
    }

    private func refreshInputVolume(deviceID: AudioDeviceID?, notificationSequence: UInt64?) {
        guard let deviceID else {
            removeInputObservations()
            inputVolume = nil
            isInputVolumeSettable = false
            if inputVolumeRequest != nil { inputVolumeFeedback = .inputVolumeUnavailable }
            return
        }
        if let request = inputVolumeRequest, request.deviceID != deviceID {
            inputVolumeRequest = nil
            inputVolumeFeedback = nil
        }
        let channels = Array(Set(backend.inputVolumeChannels(deviceID: deviceID))).sorted()
        bindInputObservations(deviceID: deviceID, channels: Set(channels))
        let valuesByChannel = Dictionary(uniqueKeysWithValues: channels.compactMap { channel -> (AudioObjectPropertyElement, Float32)? in
            guard let value = backend.inputVolume(deviceID: deviceID, channel: channel),
                  value.isFinite, (0...1).contains(value) else { return nil }
            return (channel, value)
        })
        let readBackIsComplete = !channels.isEmpty && valuesByChannel.count == channels.count
        inputVolume = readBackIsComplete ? Double(valuesByChannel.values.reduce(0, +) / Float32(valuesByChannel.count)) : nil
        isInputVolumeSettable = !channels.isEmpty && channels.allSatisfy { backend.inputVolumeIsSettable(deviceID: deviceID, channel: $0) }

        guard let request = inputVolumeRequest else {
            if notificationSequence != nil, readBackIsComplete, isInputVolumeSettable, inputVolumeFeedback == .inputVolumeUnavailable {
                inputVolumeFeedback = nil
            }
            return
        }
        guard readBackIsComplete else {
            inputVolumeFeedback = request.writeFailed ? .inputVolumeFailed : .inputVolumeUnavailable
            return
        }
        let requestedChannelsArePresent = request.channels.isSubset(of: Set(channels))
        let recoveredFromFailedWrite = requestedChannelsArePresent && request.channels.allSatisfy { channel in
            guard let value = valuesByChannel[channel] else { return false }
            return abs(value - request.value) <= 0.005
        }
        let actualValuesChanged = request.channels.contains { channel in valuesByChannel[channel] != request.previousValues[channel] }
        let actualValuesMatchRequest = request.channels.allSatisfy { channel in valuesByChannel[channel] == request.value }
        let notificationIsAfterRequest = notificationSequence.map { $0 > request.notificationBoundary } ?? false
        if notificationIsAfterRequest, requestedChannelsArePresent,
           (request.writeFailed ? recoveredFromFailedWrite : (actualValuesChanged || actualValuesMatchRequest)) {
            inputVolumeRequest = nil
            inputVolumeFeedback = nil
        } else {
            inputVolumeFeedback = request.writeFailed ? .inputVolumeFailed : .inputVolumeUnconfirmed
        }
    }

    private func bindInputObservations(deviceID: AudioDeviceID, channels: Set<AudioObjectPropertyElement>) {
        guard isStarted else { return }
        if observedInputDeviceID != deviceID {
            removeInputObservations()
            observedInputDeviceID = deviceID
        }
        for channel in Array(inputObservations.keys) where !channels.contains(channel) {
            inputObservations.removeValue(forKey: channel)?.observation.cancel()
        }
        for channel in channels.sorted() where inputObservations[channel] == nil {
            let bindingID = UUID()
            if let observation = backend.observeInputVolume(deviceID: deviceID, channel: channel, handler: { [weak self] sequence in
                guard let self, self.isStarted, self.observedInputDeviceID == deviceID,
                      self.inputObservations[channel]?.id == bindingID else { return }
                if self.inputVolumeWriteIsInProgress {
                    if let request = self.inputVolumeRequest, sequence > request.notificationBoundary {
                        self.inputVolumeNotificationDuringWrite = max(self.inputVolumeNotificationDuringWrite ?? 0, sequence)
                    }
                    self.refresh()
                } else {
                    self.refresh(volumeNotification: sequence)
                }
            }) {
                inputObservations[channel] = ObservationBinding(id: bindingID, observation: observation)
            }
        }
    }

    private func removeInputObservations() {
        observedInputDeviceID = nil
        for binding in inputObservations.values {
            binding.observation.cancel()
        }
        inputObservations.removeAll()
    }

    deinit {
        for binding in systemObservations.values {
            binding.observation.cancel()
        }
        for binding in inputObservations.values {
            binding.observation.cancel()
        }
    }
}
