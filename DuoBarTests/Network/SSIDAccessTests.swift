@testable import DuoBarKit
import DuoBarCore
import XCTest
@testable import DuoBar

final class SSIDHardwareDiagnosticTests: XCTestCase {
    func testDiagnosticReportIncludesEveryHardwareCaptureField() {
        let diagnostic = SSIDHardwareDiagnostic(
            authorization: .authorized,
            applicationIsActive: true,
            interfaceName: "en0",
            isWiFiPoweredOn: true,
            rawSSID: nil,
            networkStatusSSID: nil,
            pathDescription: "Wi-Fi",
            rssi: -58,
            refreshReason: .manual,
            locationRequestAttempted: true,
            locationRequestIssuedWhileActive: true,
            lastLocationRequestTrigger: .popoverOpened
        )

        let report = diagnostic.copyableReport
        XCTAssertTrue(report.contains("Location authorization: Authorized"))
        XCTAssertTrue(report.contains("Application active: Yes"))
        XCTAssertTrue(report.contains("Wi-Fi interface: en0"))
        XCTAssertTrue(report.contains("Wi-Fi power: On"))
        XCTAssertTrue(report.contains("CoreWLAN SSID raw result: nil"))
        XCTAssertTrue(report.contains("NetworkStatus SSID: nil"))
        XCTAssertTrue(report.contains("NWPath: Wi-Fi"))
        XCTAssertTrue(report.contains("RSSI: -58"))
        XCTAssertTrue(report.contains("Last SSID refresh reason: manual"))
        XCTAssertTrue(report.contains("Location request attempted: Yes"))
        XCTAssertTrue(report.contains("Location request issued while active: Yes"))
        XCTAssertTrue(report.contains("Last location request trigger: popover opened"))
    }
}
