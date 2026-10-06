import Foundation

public enum StatusPriority: Int, Comparable, Sendable {
    case informational = 10
    case attention = 20
    case critical = 30

    public static func < (lhs: StatusPriority, rhs: StatusPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct StatusEvent: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case charging
        case networkDisconnected
        case lowBattery
        case audioDeviceConnected(AudioDeviceStatus)
    }

    public let id: UUID
    public let kind: Kind
    public let priority: StatusPriority
    public let duration: TimeInterval

    public init(
        kind: Kind,
        priority: StatusPriority,
        duration: TimeInterval = 2.2,
        id: UUID = UUID()
    ) {
        self.id = id
        self.kind = kind
        self.priority = priority
        self.duration = duration
    }
}

public enum StatusPresentation: Equatable, Sendable {
    case normal
    case event(StatusEvent)

    public var event: StatusEvent? {
        guard case let .event(event) = self else { return nil }
        return event
    }
}

public enum StatusEventDetector {
    public static func events(from old: SystemStatus, to new: SystemStatus) -> [StatusEvent] {
        var events: [StatusEvent] = []

        if old.battery.isAvailable,
           !old.battery.isCharging,
           new.battery.isCharging {
            events.append(StatusEvent(kind: .charging, priority: .informational))
        }

        if old.network.isAvailable,
           old.network.isConnected,
           !new.network.isConnected {
            events.append(StatusEvent(kind: .networkDisconnected, priority: .attention))
        }

        let oldPercentage = old.battery.percentage ?? 101
        let newPercentage = new.battery.percentage ?? 101
        if new.battery.isAvailable,
           !new.battery.isCharging,
           oldPercentage > 10,
           newPercentage <= 10 {
            events.append(StatusEvent(kind: .lowBattery, priority: .critical, duration: 3.2))
        }

        if old.audio.isAvailable {
            let oldDeviceIDs = Set(old.audio.connectedBluetoothOutputs.map(\.uid))
            if let connectedDevice = new.audio.connectedBluetoothOutputs.first(where: { !oldDeviceIDs.contains($0.uid) }) {
                events.append(
                    StatusEvent(
                        kind: .audioDeviceConnected(connectedDevice),
                        priority: .informational,
                        duration: 1.45
                    )
                )
            }
        }

        return events.sorted { lhs, rhs in
            if lhs.priority == rhs.priority { return lhs.duration > rhs.duration }
            return lhs.priority > rhs.priority
        }
    }
}
