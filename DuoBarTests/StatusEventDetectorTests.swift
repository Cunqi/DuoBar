import XCTest
@testable import DuoBar

final class StatusEventDetectorTests: XCTestCase {
    func testChargingTransitionCreatesInformationalEvent() {
        let old = makeStatus(battery: battery(percentage: 50, charging: false))
        let new = makeStatus(battery: battery(percentage: 51, charging: true))

        let events = StatusEventDetector.events(from: old, to: new)

        XCTAssertEqual(events.map(\.kind), [.charging])
        XCTAssertEqual(events.first?.priority, .informational)
    }

    func testInitialServicePopulationDoesNotCreateDisconnectEvents() {
        let new = makeStatus(
            battery: battery(percentage: 80, charging: false),
            wifi: WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: false, ssid: nil, rssi: nil),
            bluetooth: BluetoothStatus(isAvailable: true, isPoweredOn: false)
        )

        XCTAssertTrue(StatusEventDetector.events(from: .unavailable, to: new).isEmpty)
    }

    func testDisconnectAndLowBatteryAreSortedByPriority() {
        let old = makeStatus(
            battery: battery(percentage: 20, charging: false),
            wifi: WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: true, ssid: "Studio", rssi: -45)
        )
        let new = makeStatus(
            battery: battery(percentage: 8, charging: false),
            wifi: WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: false, ssid: nil, rssi: nil)
        )

        XCTAssertEqual(StatusEventDetector.events(from: old, to: new).map(\.kind), [.lowBattery, .wifiDisconnected])
    }

    func testBluetoothPowerOffCreatesEvent() {
        let old = makeStatus(bluetooth: BluetoothStatus(isAvailable: true, isPoweredOn: true))
        let new = makeStatus(bluetooth: BluetoothStatus(isAvailable: true, isPoweredOn: false))

        XCTAssertEqual(StatusEventDetector.events(from: old, to: new).map(\.kind), [.bluetoothDisabled])
    }

    func testWiFiSignalStrengthIsClamped() {
        XCTAssertEqual(WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: true, ssid: nil, rssi: -30).signalStrength, 1)
        XCTAssertEqual(WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: true, ssid: nil, rssi: -100).signalStrength, 0)
        XCTAssertNil(WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: false, ssid: nil, rssi: nil).signalStrength)
    }

    private func makeStatus(
        battery: BatteryStatus = .unavailable,
        wifi: WiFiStatus = .unavailable,
        bluetooth: BluetoothStatus = .unavailable
    ) -> SystemStatus {
        SystemStatus(battery: battery, wifi: wifi, bluetooth: bluetooth)
    }

    private func battery(percentage: Int, charging: Bool) -> BatteryStatus {
        BatteryStatus(
            percentage: percentage,
            isCharging: charging,
            isPluggedIn: charging,
            isFullyCharged: false,
            isAvailable: true
        )
    }
}
