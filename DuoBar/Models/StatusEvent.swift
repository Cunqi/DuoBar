import Foundation

enum StatusPriority: Int, Comparable, Sendable {
    case informational = 10
    case attention = 20
    case critical = 30

    static func < (lhs: StatusPriority, rhs: StatusPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct StatusEvent: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case charging
        case wifiDisconnected
        case bluetoothDisabled
        case lowBattery
    }

    let id: UUID
    let kind: Kind
    let priority: StatusPriority
    let duration: TimeInterval

    init(
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

enum StatusPresentation: Equatable, Sendable {
    case normal
    case event(StatusEvent)

    var event: StatusEvent? {
        guard case let .event(event) = self else { return nil }
        return event
    }
}

enum StatusEventDetector {
    static func events(from old: SystemStatus, to new: SystemStatus) -> [StatusEvent] {
        var events: [StatusEvent] = []

        if old.battery.isAvailable,
           !old.battery.isCharging,
           new.battery.isCharging {
            events.append(StatusEvent(kind: .charging, priority: .informational))
        }

        if old.wifi.isAvailable,
           old.wifi.isConnected,
           !new.wifi.isConnected {
            events.append(StatusEvent(kind: .wifiDisconnected, priority: .attention))
        }

        if old.bluetooth.isAvailable,
           old.bluetooth.isPoweredOn,
           !new.bluetooth.isPoweredOn {
            events.append(StatusEvent(kind: .bluetoothDisabled, priority: .attention))
        }

        let oldPercentage = old.battery.percentage ?? 101
        let newPercentage = new.battery.percentage ?? 101
        if new.battery.isAvailable,
           !new.battery.isCharging,
           oldPercentage > 10,
           newPercentage <= 10 {
            events.append(StatusEvent(kind: .lowBattery, priority: .critical, duration: 3.2))
        }

        return events.sorted { $0.priority > $1.priority }
    }
}
