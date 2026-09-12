import Foundation

struct DuoGlyphState: Equatable {
    let batteryProgress: Double
    let batteryArcOpacity: Double
    let isCharging: Bool
    let wifiLevel: WiFiSignalLevel
    let bluetoothDotOpacity: Double

    init(status: SystemStatus) {
        let battery = status.battery
        if battery.isFullyCharged {
            batteryProgress = 1
        } else if battery.isAvailable, let percentage = battery.percentage {
            batteryProgress = min(max(Double(percentage) / 100, 0), 1)
        } else {
            batteryProgress = 1
        }
        batteryArcOpacity = battery.isAvailable ? 1 : 0.22
        isCharging = battery.isAvailable && battery.isCharging
        wifiLevel = status.wifi.signalLevel

        let bluetooth = status.bluetooth
        if !bluetooth.isAvailable {
            bluetoothDotOpacity = 0.14
        } else if bluetooth.isPoweredOn {
            bluetoothDotOpacity = 1
        } else {
            bluetoothDotOpacity = 0.25
        }
    }
}
