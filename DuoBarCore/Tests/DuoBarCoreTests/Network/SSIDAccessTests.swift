import XCTest
@testable import DuoBarCore

final class SSIDAccessTests: XCTestCase {
    func testAvailableSSIDIsNormalizedAndStoredWithoutFabrication() {
        XCTAssertEqual(SSIDValue.normalized("  Studio Wi-Fi  "), "Studio Wi-Fi")

        let status = wifiStatus(ssid: SSIDValue.normalized("Studio Wi-Fi"))
        XCTAssertEqual(status.ssid, "Studio Wi-Fi")
    }

    func testNilOrEmptySSIDRemainsUnavailable() {
        XCTAssertNil(SSIDValue.normalized(nil))
        XCTAssertNil(SSIDValue.normalized("   \n"))
        XCTAssertNil(wifiStatus(ssid: nil).ssid)
    }

    func testAuthorizationRequestWaitsUntilApplicationIsActive() {
        var coordinator = SSIDAccessCoordinator()

        XCTAssertEqual(
            coordinator.requestAccess(
                authorization: .notDetermined,
                applicationIsActive: false,
                trigger: .popoverOpened
            ),
            []
        )
        XCTAssertTrue(coordinator.isWaitingForApplicationActivation)
        XCTAssertEqual(
            coordinator.applicationDidBecomeActive(authorization: .notDetermined),
            [.requestAuthorization(trigger: .appBecameActive)]
        )
        XCTAssertTrue(coordinator.hasIssuedAuthorizationRequest)
        XCTAssertTrue(coordinator.wasAuthorizationRequestIssuedWhileActive)
    }

    func testAlreadyActiveRequestIsNotMissed() {
        var coordinator = SSIDAccessCoordinator()

        XCTAssertEqual(
            coordinator.requestAccess(
                authorization: .notDetermined,
                applicationIsActive: true,
                trigger: .popoverOpened
            ),
            [.requestAuthorization(trigger: .popoverOpened)]
        )
        XCTAssertTrue(coordinator.hasAttemptedAuthorizationRequest)
        XCTAssertTrue(coordinator.hasIssuedAuthorizationRequest)
        XCTAssertEqual(coordinator.lastRequestTrigger, .popoverOpened)
    }

    func testValidAuthorizationRequestIsIssuedOnlyOnce() {
        var coordinator = SSIDAccessCoordinator()

        let first = coordinator.requestAccess(
            authorization: .notDetermined,
            applicationIsActive: true,
            trigger: .popoverOpened
        )
        let second = coordinator.requestAccess(
            authorization: .notDetermined,
            applicationIsActive: true,
            trigger: .popoverOpened
        )

        XCTAssertEqual(first, [.requestAuthorization(trigger: .popoverOpened)])
        XCTAssertEqual(second, [])
    }

    func testInactiveAttemptDoesNotConsumeRequestGuard() {
        var coordinator = SSIDAccessCoordinator()

        XCTAssertEqual(
            coordinator.requestAccess(
                authorization: .notDetermined,
                applicationIsActive: false,
                trigger: .popoverOpened
            ),
            []
        )
        XCTAssertTrue(coordinator.hasAttemptedAuthorizationRequest)
        XCTAssertFalse(coordinator.hasIssuedAuthorizationRequest)

        XCTAssertEqual(
            coordinator.requestAccess(
                authorization: .notDetermined,
                applicationIsActive: true,
                trigger: .popoverOpened
            ),
            [.requestAuthorization(trigger: .popoverOpened)]
        )
    }

    func testDeterminedAuthorizationNeverRequestsPermission() {
        for authorization in [SSIDAuthorizationState.authorized, .denied, .restricted] {
            var coordinator = SSIDAccessCoordinator()
            let actions = coordinator.requestAccess(
                authorization: authorization,
                applicationIsActive: true,
                trigger: .popoverOpened
            )

            XCTAssertFalse(actions.contains { action in
                if case .requestAuthorization = action { return true }
                return false
            })
            XCTAssertFalse(coordinator.hasAttemptedAuthorizationRequest)
            XCTAssertFalse(coordinator.hasIssuedAuthorizationRequest)
        }
    }

    func testAuthorizationBecomingAllowedRequestsPromptRefresh() {
        var coordinator = SSIDAccessCoordinator()
        _ = coordinator.requestAccess(
            authorization: .notDetermined,
            applicationIsActive: true,
            trigger: .popoverOpened
        )

        XCTAssertEqual(coordinator.authorizationDidChange(to: .authorized), [.refresh])
    }

    func testDeniedAuthorizationUsesFallbackWithoutRepeatedPermissionRequest() {
        var coordinator = SSIDAccessCoordinator()

        for _ in 0..<3 {
            let actions = coordinator.requestAccess(
                authorization: .denied,
                applicationIsActive: true,
                trigger: .popoverOpened
            )
            XCTAssertEqual(actions, [.refresh])
            XCTAssertFalse(actions.contains { action in
                if case .requestAuthorization = action { return true }
                return false
            })
        }
    }

    func testWiFiReconnectCanReplaceNilSSIDWithRealCoreWLANValue() {
        let disconnected = wifiStatus(ssid: nil, connected: false, poweredOn: false)
        let reconnecting = wifiStatus(ssid: nil, connected: false, poweredOn: true)
        let reconnected = wifiStatus(ssid: SSIDValue.normalized("Home"), connected: true, poweredOn: true)

        XCTAssertNil(disconnected.ssid)
        XCTAssertNil(reconnecting.ssid)
        XCTAssertEqual(reconnected.ssid, "Home")
    }

    func testEthernetStateDoesNotAcquireOrFabricateSSID() {
        let ethernet = NetworkStatus(
            isAvailable: true,
            isConnected: true,
            transport: .ethernet,
            interfaceName: "en1",
            isWiFiPoweredOn: true,
            ssid: nil,
            rssi: nil
        )

        XCTAssertEqual(ethernet.transport, .ethernet)
        XCTAssertNil(ethernet.ssid)
    }


    private func wifiStatus(
        ssid: String?,
        connected: Bool = true,
        poweredOn: Bool = true
    ) -> NetworkStatus {
        NetworkStatus(
            isAvailable: true,
            isConnected: connected,
            transport: .wifi,
            interfaceName: "en0",
            isWiFiPoweredOn: poweredOn,
            ssid: ssid,
            rssi: connected ? -50 : nil
        )
    }
}
