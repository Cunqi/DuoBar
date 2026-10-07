import CoreAudio
import DuoBarCore
import Foundation
import Testing
@testable import DuoBar

@Suite("音频控制结果与监听生命周期")
@MainActor
struct AudioDeviceSwitcherRegressionTests {
    @Test("设备切换被系统拒绝时保留实际设备并显示失败", arguments: [AudioDeviceDirection.output, .input])
    func rejectedDeviceSwitchPreservesActualSelection(direction: AudioDeviceDirection) {
        let backend = FakeAudioDeviceBackend()
        backend.defaultWriteStatus = -50
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        let target = direction == .output ? backend.outputB : backend.inputB

        switcher.setDefault(target, direction: direction)

        let options = direction == .output ? switcher.outputs : switcher.inputs
        let feedback = direction == .output ? switcher.outputSwitchFeedback : switcher.inputSwitchFeedback
        #expect(options.first(where: \.isDefault)?.id == (direction == .output ? backend.outputA.id : backend.inputA.id))
        #expect(feedback == .switchFailed)
        switcher.stop()
    }

    @Test("切换请求接受后先显示未确认直到通知与实际设备一致", arguments: [AudioDeviceDirection.output, .input])
    func acceptedDeviceSwitchWaitsForConfirmedSelection(direction: AudioDeviceDirection) {
        let backend = FakeAudioDeviceBackend()
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        let target = direction == .output ? backend.outputB : backend.inputB

        switcher.setDefault(target, direction: direction)

        #expect((direction == .output ? switcher.outputSwitchFeedback : switcher.inputSwitchFeedback) == .switchUnconfirmed)
        #expect((direction == .output ? switcher.outputs : switcher.inputs).first(where: \.isDefault)?.id != target.id)
        backend.setActualDefault(target.id, direction: direction)
        backend.emit(.system(direction == .output ? .defaultOutput : .defaultInput))
        #expect((direction == .output ? switcher.outputs : switcher.inputs).first(where: \.isDefault)?.id == target.id)
        #expect((direction == .output ? switcher.outputSwitchFeedback : switcher.inputSwitchFeedback) == nil)
        switcher.stop()
    }

    @Test("已失败的设备切换在实际恢复后清除对应错误", arguments: [AudioDeviceDirection.output, .input])
    func deviceSwitchErrorClearsWhenActualSelectionRecovers(direction: AudioDeviceDirection) {
        let backend = FakeAudioDeviceBackend()
        backend.defaultWriteStatus = -50
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        let target = direction == .output ? backend.outputB : backend.inputB
        switcher.setDefault(target, direction: direction)
        #expect((direction == .output ? switcher.outputSwitchFeedback : switcher.inputSwitchFeedback) == .switchFailed)

        backend.setActualDefault(target.id, direction: direction)
        backend.emit(.system(direction == .output ? .defaultOutput : .defaultInput))

        #expect((direction == .output ? switcher.outputSwitchFeedback : switcher.inputSwitchFeedback) == nil)
        switcher.stop()
    }

    @Test("输入音量写入失败时显示读回的实际值和失败提示")
    func rejectedInputVolumeWriteKeepsActualValue() {
        let backend = FakeAudioDeviceBackend()
        backend.inputWriteStatuses = [1: -50, 2: -50]
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()

        switcher.setInputVolume(0.8)

        #expect(abs((switcher.inputVolume ?? -1) - 0.2) < 0.0001)
        #expect(switcher.inputVolumeFeedback == .inputVolumeFailed)
        switcher.stop()
    }

    @Test("部分输入声道写入失败时按全部实际读数呈现且报告失败")
    func partiallyRejectedInputVolumeWriteReadsAllChannels() {
        let backend = FakeAudioDeviceBackend()
        backend.inputWriteStatuses = [2: -50]
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()

        switcher.setInputVolume(0.8)

        #expect(backend.inputWriteChannels == [1, 2])
        #expect(abs((switcher.inputVolume ?? -1) - 0.5) < 0.0001)
        #expect(switcher.inputVolumeFeedback == .inputVolumeFailed)
        switcher.stop()
    }

    @Test("异步输入音量请求不提前显示请求值且通知确认后清除提示")
    func asynchronousInputVolumeUsesReadBackUntilConfirmed() {
        let backend = FakeAudioDeviceBackend()
        backend.appliesInputWrites = false
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()

        switcher.setInputVolume(0.8)

        #expect(abs((switcher.inputVolume ?? -1) - 0.2) < 0.0001)
        #expect(switcher.inputVolumeFeedback == .inputVolumeUnconfirmed)
        backend.inputVolumes[backend.inputA.id] = [1: 0.8, 2: 0.8]
        backend.emit(.input(backend.inputA.id, 2))
        #expect(abs((switcher.inputVolume ?? -1) - 0.8) < 0.0001)
        #expect(switcher.inputVolumeFeedback == nil)
        switcher.stop()
    }

    @Test("输入读回缺失时不制造音量值且恢复后清除提示")
    func unavailableInputReadBackDoesNotFabricateSuccess() {
        let backend = FakeAudioDeviceBackend()
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        backend.failsInputReads = true

        switcher.setInputVolume(0.8)

        #expect(switcher.inputVolume == nil)
        #expect(switcher.inputVolumeFeedback == .inputVolumeUnavailable)
        backend.failsInputReads = false
        backend.emit(.input(backend.inputA.id, 1))
        #expect(abs((switcher.inputVolume ?? -1) - 0.8) < 0.0001)
        #expect(switcher.inputVolumeFeedback == nil)
        switcher.stop()
    }

    @Test("驱动量化输入增益后以完整实际读回确认成功")
    func quantizedInputVolumeConfirmsTheActualValue() {
        let backend = FakeAudioDeviceBackend()
        backend.appliesInputWrites = false
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        switcher.setInputVolume(0.83)
        #expect(switcher.inputVolumeFeedback == .inputVolumeUnconfirmed)

        backend.inputVolumes[backend.inputA.id] = [1: 0.8, 2: 0.8]
        backend.emit(.input(backend.inputA.id, 1))

        #expect(abs((switcher.inputVolume ?? -1) - 0.8) < 0.0001)
        #expect(switcher.inputVolumeFeedback == nil)
        switcher.stop()
    }

    @Test("实际输入刚切换时先绑定声道再处理写入期间的通知")
    func inputVolumeBindsBeforeWritingTheActualDevice() {
        let backend = FakeAudioDeviceBackend()
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        backend.currentInputID = backend.inputB.id
        backend.notifiesDuringInputWrites = true

        switcher.setInputVolume(0.7)

        #expect(switcher.defaultInput?.id == backend.inputB.id)
        #expect(abs((switcher.inputVolume ?? -1) - 0.7) < 0.0001)
        #expect(switcher.inputVolumeFeedback == nil)
        #expect(backend.activeTargets.filter { if case .input = $0 { true } else { false } } == [.input(backend.inputB.id, 0)])
        switcher.stop()
    }

    @Test("成功的后续输入音量操作会清除先前失败且不清除输出错误")
    func confirmedInputVolumeRetryClearsOnlyItsOwnError() {
        let backend = FakeAudioDeviceBackend()
        backend.defaultWriteStatus = -50
        backend.inputWriteStatuses = [1: -50, 2: -50]
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        switcher.setDefault(backend.outputB, direction: .output)
        switcher.setInputVolume(0.8)
        #expect(switcher.inputVolumeFeedback == .inputVolumeFailed)

        backend.inputWriteStatuses = [:]
        switcher.setInputVolume(0.6)
        backend.emit(.input(backend.inputA.id, 1))

        #expect(switcher.inputVolumeFeedback == nil)
        #expect(switcher.outputSwitchFeedback == .switchFailed)
        switcher.stop()
    }

    @Test("重复启动不重复绑定并观察全部输入音量声道")
    func repeatedStartDoesNotDuplicateAllChannelBindings() {
        let backend = FakeAudioDeviceBackend()
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        switcher.start()

        #expect(backend.activeTargets.filter { if case .system = $0 { true } else { false } }.count == AudioDeviceSystemProperty.allCases.count)
        #expect(backend.activeTargets.filter { if case .input = $0 { true } else { false } } == [.input(backend.inputA.id, 1), .input(backend.inputA.id, 2)])
        #expect(Set(backend.activeTargets).count == backend.activeTargets.count)
        switcher.stop()
    }

    @Test("输入设备往返切换会撤销旧声道监听且不会累积重复绑定")
    func switchingInputBackAndForthReplacesOldBindings() {
        let backend = FakeAudioDeviceBackend()
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        backend.currentInputID = backend.inputB.id
        backend.emit(.system(.defaultInput))
        #expect(backend.activeTargets.filter { if case .input = $0 { true } else { false } } == [.input(backend.inputB.id, 0)])

        backend.currentInputID = backend.inputA.id
        backend.emit(.system(.defaultInput))

        #expect(backend.activeTargets.filter { if case .input = $0 { true } else { false } } == [.input(backend.inputA.id, 1), .input(backend.inputA.id, 2)])
        let reads = backend.deviceReadCount
        backend.emit(.input(backend.inputB.id, 0))
        #expect(backend.deviceReadCount == reads)
        switcher.stop()
    }

    @Test("默认输入消失时释放所有输入声道监听")
    func missingDefaultInputReleasesVolumeBindings() {
        let backend = FakeAudioDeviceBackend()
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()

        backend.currentInputID = nil
        backend.emit(.system(.defaultInput))

        #expect(switcher.inputVolume == nil)
        #expect(!switcher.isInputVolumeSettable)
        #expect(!backend.activeTargets.contains { if case .input = $0 { true } else { false } })
        switcher.stop()
    }

    @Test("停止释放全部监听并忽略已经排队的旧回调")
    func stopReleasesBindingsAndIgnoresLateCallbacks() throws {
        let backend = FakeAudioDeviceBackend()
        let switcher = AudioDeviceSwitcher(backend: backend)
        switcher.start()
        let callback = try #require(backend.handler(for: .system(.devices)))
        switcher.stop()
        switcher.stop()
        let reads = backend.deviceReadCount

        callback()

        #expect(backend.activeTargets.isEmpty)
        #expect(backend.deviceReadCount == reads)
    }

    @Test("销毁控制器会释放系统与全部输入声道监听")
    func deinitializationReleasesEveryObservation() {
        let backend = FakeAudioDeviceBackend()
        var switcher: AudioDeviceSwitcher? = AudioDeviceSwitcher(backend: backend)
        weak var weakSwitcher = switcher
        switcher?.start()
        #expect(!backend.activeTargets.isEmpty)

        switcher = nil

        #expect(weakSwitcher == nil)
        #expect(backend.activeTargets.isEmpty)
    }
}

private enum AudioObservationTarget: Hashable {
    case system(AudioDeviceSystemProperty)
    case input(AudioDeviceID, AudioObjectPropertyElement)
}

private final class FakeAudioDeviceBackend: AudioDeviceBackend {
    let outputA = AudioDeviceOption(id: 20, name: "Output A", isDefault: true)
    let outputB = AudioDeviceOption(id: 21, name: "Output B", isDefault: false)
    let inputA = AudioDeviceOption(id: 10, name: "Input A", isDefault: true)
    let inputB = AudioDeviceOption(id: 11, name: "Input B", isDefault: false)
    var currentOutputID: AudioDeviceID? = 20
    var currentInputID: AudioDeviceID? = 10
    var defaultWriteStatus: OSStatus = noErr
    var inputWriteStatuses: [AudioObjectPropertyElement: OSStatus] = [:]
    var appliesInputWrites = true
    var notifiesDuringInputWrites = false
    var failsInputReads = false
    var inputVolumes: [AudioDeviceID: [AudioObjectPropertyElement: Float32]] = [10: [1: 0.2, 2: 0.2], 11: [0: 0.3]]
    private(set) var inputWriteChannels: [AudioObjectPropertyElement] = []
    private(set) var deviceReadCount = 0
    private var observations: [UUID: (AudioObservationTarget, @MainActor () -> Void)] = [:]

    var activeTargets: [AudioObservationTarget] {
        observations.values.map(\.0).sorted { String(describing: $0) < String(describing: $1) }
    }

    func devices() -> [AudioDeviceDescriptor] {
        deviceReadCount += 1
        return [
            AudioDeviceDescriptor(id: outputA.id, name: outputA.name, hasOutput: true, hasInput: false),
            AudioDeviceDescriptor(id: outputB.id, name: outputB.name, hasOutput: true, hasInput: false),
            AudioDeviceDescriptor(id: inputA.id, name: inputA.name, hasOutput: false, hasInput: true),
            AudioDeviceDescriptor(id: inputB.id, name: inputB.name, hasOutput: false, hasInput: true)
        ]
    }

    func defaultDevice(direction: AudioDeviceDirection) -> AudioDeviceID? {
        direction == .output ? currentOutputID : currentInputID
    }

    func setDefaultDevice(_ deviceID: AudioDeviceID, direction: AudioDeviceDirection) -> OSStatus {
        defaultWriteStatus
    }

    func setActualDefault(_ deviceID: AudioDeviceID, direction: AudioDeviceDirection) {
        if direction == .output { currentOutputID = deviceID } else { currentInputID = deviceID }
    }

    func inputVolumeChannels(deviceID: AudioDeviceID) -> [AudioObjectPropertyElement] {
        inputVolumes[deviceID]?.keys.sorted() ?? []
    }

    func inputVolume(deviceID: AudioDeviceID, channel: AudioObjectPropertyElement) -> Float32? {
        failsInputReads ? nil : inputVolumes[deviceID]?[channel]
    }

    func inputVolumeIsSettable(deviceID: AudioDeviceID, channel: AudioObjectPropertyElement) -> Bool {
        true
    }

    func setInputVolume(_ value: Float32, deviceID: AudioDeviceID, channel: AudioObjectPropertyElement) -> OSStatus {
        inputWriteChannels.append(channel)
        let result = inputWriteStatuses[channel] ?? noErr
        if result == noErr, appliesInputWrites { inputVolumes[deviceID]?[channel] = value }
        if notifiesDuringInputWrites {
            MainActor.assumeIsolated { emit(.input(deviceID, channel)) }
        }
        return result
    }

    func observeSystem(_ property: AudioDeviceSystemProperty, handler: @escaping @MainActor () -> Void) -> AudioDeviceObservation? {
        observe(.system(property), handler: handler)
    }

    func observeInputVolume(deviceID: AudioDeviceID, channel: AudioObjectPropertyElement, handler: @escaping @MainActor () -> Void) -> AudioDeviceObservation? {
        observe(.input(deviceID, channel), handler: handler)
    }

    @MainActor
    func emit(_ target: AudioObservationTarget) {
        for callback in observations.values.filter({ $0.0 == target }).map(\.1) { callback() }
    }

    func handler(for target: AudioObservationTarget) -> (@MainActor () -> Void)? {
        observations.values.first(where: { $0.0 == target })?.1
    }

    private func observe(_ target: AudioObservationTarget, handler: @escaping @MainActor () -> Void) -> AudioDeviceObservation {
        let id = UUID()
        observations[id] = (target, handler)
        return AudioDeviceObservation { [weak self] in self?.observations.removeValue(forKey: id) }
    }
}
