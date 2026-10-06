import Foundation

public enum GlyphWiFiSignalLevel: Hashable, Sendable {
    case strong
    case medium
    case weak
    case disconnected
    case disabled
    case unavailable
}

public enum GlyphCenterState: Hashable, Sendable {
    case wifi(GlyphWiFiSignalLevel)
    case ethernet
    case offline
    case other
    case unavailable
    case airPodsPro
    case airPodsMax
    case airPods
    case headphones
    case audioDevice
    case performanceCPU
    case performanceMemory
    case performanceThermal
}

public enum GlyphRingMode: Equatable, Sendable {
    case battery
    case adaptive
}

public enum GlyphBatteryBoltPlacement: Equatable, Sendable {
    case none
    case topGap
}

public enum GlyphBatteryColorRole: Equatable, Sendable {
    case monochrome
    case charging
    case lowPowerMode
    case lowBattery
}

public enum GlyphSemanticFeedback: Equatable, Sendable {
    case none
    case charging
    case lowBattery
    case audioConnected
}

public struct GlyphBatteryPresentation: Equatable, Sendable {
    public let boltPlacement: GlyphBatteryBoltPlacement
    public let colorRole: GlyphBatteryColorRole

    public init(boltPlacement: GlyphBatteryBoltPlacement, colorRole: GlyphBatteryColorRole) {
        self.boltPlacement = boltPlacement
        self.colorRole = colorRole
    }
}

public struct GlyphRingPresentation: Equatable, Sendable {
    public let mode: GlyphRingMode
    public let progress: Double
    public let opacity: Double
    public let batteryPresentation: GlyphBatteryPresentation

    public init(mode: GlyphRingMode, progress: Double, opacity: Double, batteryPresentation: GlyphBatteryPresentation) {
        self.mode = mode
        self.progress = progress
        self.opacity = opacity
        self.batteryPresentation = batteryPresentation
    }
}

public struct GlyphRenderState: Equatable, Sendable {
    public let ringPresentation: GlyphRingPresentation
    public let centerState: GlyphCenterState
    public let volumeActiveDotCount: Int?
    public let feedback: GlyphSemanticFeedback
    public let audioEventID: UUID?
    public let nonChargingBatteryColorRole: GlyphBatteryColorRole

    public init(
        ringPresentation: GlyphRingPresentation,
        centerState: GlyphCenterState,
        volumeActiveDotCount: Int?,
        feedback: GlyphSemanticFeedback,
        audioEventID: UUID?,
        nonChargingBatteryColorRole: GlyphBatteryColorRole
    ) {
        self.ringPresentation = ringPresentation
        self.centerState = centerState
        self.volumeActiveDotCount = volumeActiveDotCount
        self.feedback = feedback
        self.audioEventID = audioEventID
        self.nonChargingBatteryColorRole = nonChargingBatteryColorRole
    }

    var batteryProgress: Double { ringPresentation.progress }
    var batteryArcOpacity: Double { ringPresentation.opacity }
    var batteryPresentation: GlyphBatteryPresentation { ringPresentation.batteryPresentation }
}
