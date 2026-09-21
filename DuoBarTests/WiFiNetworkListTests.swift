import XCTest
@testable import DuoBar

final class WiFiNetworkListTests: XCTestCase {
    func testCurrentNetworkComesFirstThenStrongerSignals() {
        let options = WiFiNetworkList.options(
            from: [
                ScannedWiFiNetwork(ssid: "Cafe", rssi: -80, security: .open),
                ScannedWiFiNetwork(ssid: "Office", rssi: -50, security: .personal),
                ScannedWiFiNetwork(ssid: "Home", rssi: -70, security: .personal)
            ],
            currentSSID: "Home",
            knownSSIDs: []
        )

        XCTAssertEqual(options.map(\.ssid), ["Home", "Office", "Cafe"])
        XCTAssertEqual(options.map(\.isCurrent), [true, false, false])
    }

    func testDuplicateNamesKeepTheStrongestAccessPoint() {
        let options = WiFiNetworkList.options(
            from: [
                ScannedWiFiNetwork(ssid: "Office", rssi: -82, security: .personal),
                ScannedWiFiNetwork(ssid: "Office", rssi: -55, security: .personal),
                ScannedWiFiNetwork(ssid: "Office", rssi: -70, security: .personal)
            ],
            currentSSID: nil,
            knownSSIDs: []
        )

        XCTAssertEqual(options.count, 1)
        XCTAssertEqual(options.first?.rssi, -55)
        XCTAssertEqual(options.first?.signalLevel, .strong)
    }

    func testHiddenAndBlankNamesAreOmitted() {
        let options = WiFiNetworkList.options(
            from: [
                ScannedWiFiNetwork(ssid: nil, rssi: -40, security: .personal),
                ScannedWiFiNetwork(ssid: "   ", rssi: -45, security: .open),
                ScannedWiFiNetwork(ssid: "Visible", rssi: -60, security: .open)
            ],
            currentSSID: nil,
            knownSSIDs: []
        )

        XCTAssertEqual(options.map(\.ssid), ["Visible"])
    }

    func testKnownNetworksAreMarked() {
        let options = WiFiNetworkList.options(
            from: [
                ScannedWiFiNetwork(ssid: "Home", rssi: -60, security: .personal),
                ScannedWiFiNetwork(ssid: "Neighbor", rssi: -65, security: .personal)
            ],
            currentSSID: nil,
            knownSSIDs: ["Home"]
        )

        XCTAssertEqual(options.map(\.isKnown), [true, false])
    }

    func testSelectingANetworkChoosesHowToJoin() {
        func action(_ security: WiFiNetworkSecurity, known: Bool = false, current: Bool = false) -> WiFiJoinAction {
            WiFiJoinAction.initial(for: WiFiNetworkOption(
                ssid: "Network",
                rssi: -60,
                security: security,
                isCurrent: current,
                isKnown: known
            ))
        }

        XCTAssertEqual(action(.personal, current: true), .none)
        XCTAssertEqual(action(.open), .associate(password: nil))
        XCTAssertEqual(action(.personal, known: true), .associate(password: nil))
        XCTAssertEqual(action(.personal), .requestPassword)
        XCTAssertEqual(action(.enterprise), .openSystemSettings)
    }

    func testFailedPasswordlessJoinOnSecuredNetworkAsksForPassword() {
        let secured = WiFiNetworkOption(ssid: "Home", rssi: -60, security: .personal, isCurrent: false, isKnown: true)
        let open = WiFiNetworkOption(ssid: "Cafe", rssi: -60, security: .open, isCurrent: false, isKnown: false)

        XCTAssertEqual(WiFiJoinAction.afterFailedAssociation(for: secured, usedPassword: false), .requestPassword)
        XCTAssertEqual(WiFiJoinAction.afterFailedAssociation(for: secured, usedPassword: true), .showFailure)
        XCTAssertEqual(WiFiJoinAction.afterFailedAssociation(for: open, usedPassword: false), .showFailure)
    }
}
