import Foundation

public struct VolumeFeedbackInteraction {
    public init() {}

    public private(set) var isEditing = false
    public private(set) var allowsVolumeUpdates = false
    private var receivedVolumeUpdate = false
    private var allWritesSucceeded = true
    private var releaseFeedbackAllowed = false
    private var finalRequestedLevel: Double?

    public mutating func beginEditing(
        previousStatus: OutputVolumeStatus,
        unmuteSucceeded: Bool
    ) {
        guard !isEditing else { return }
        isEditing = true
        allowsVolumeUpdates = true
        receivedVolumeUpdate = false
        allWritesSucceeded = true
        releaseFeedbackAllowed = previousStatus.isSettable
        finalRequestedLevel = nil

        if previousStatus.isMuted, previousStatus.isMuteSettable {
            allowsVolumeUpdates = unmuteSucceeded
            releaseFeedbackAllowed = releaseFeedbackAllowed && unmuteSucceeded
        }
    }

    public mutating func recordVolumeUpdate(
        previousStatus: OutputVolumeStatus,
        requestedLevel: Double,
        writeSucceeded: Bool
    ) {
        guard isEditing else { return }
        receivedVolumeUpdate = true
        allWritesSucceeded = allWritesSucceeded && writeSucceeded
        releaseFeedbackAllowed = releaseFeedbackAllowed && previousStatus.isSettable
        finalRequestedLevel = requestedLevel
    }

    public mutating func endEditing() -> Bool {
        guard isEditing else { return false }
        defer { reset() }

        return receivedVolumeUpdate
            && allWritesSucceeded
            && releaseFeedbackAllowed
            && (finalRequestedLevel ?? 0) > 0
    }

    public func shouldPlayForUnmute(
        previousStatus: OutputVolumeStatus,
        writeSucceeded: Bool
    ) -> Bool {
        writeSucceeded
            && previousStatus.isMuteSettable
            && previousStatus.isMuted
            && (previousStatus.level ?? 0) > 0
    }

    private mutating func reset() {
        isEditing = false
        allowsVolumeUpdates = false
        receivedVolumeUpdate = false
        allWritesSucceeded = true
        releaseFeedbackAllowed = false
        finalRequestedLevel = nil
    }
}
