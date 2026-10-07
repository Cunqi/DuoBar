@testable import DuoBarKit
import DuoBarCore
import AppKit
import XCTest
@testable import DuoBar

final class HoverPopoverAppTests: XCTestCase {
    func testDefaultIsDisabledAndClosed() {
        let interaction = HoverPopoverInteraction()
        XCTAssertFalse(interaction.isEnabled)
        XCTAssertEqual(interaction.state, .closed)
        XCTAssertEqual(PreferenceKeys.openOnHover, "duoBar.openOnHover")
    }

    func testCompletePopoverRootUsesPersistentVisibleBoundsTrackingArea() throws {
        let view = HoverTrackingContainerView(frame: NSRect(x: 0, y: 0, width: 304, height: 316))

        view.updateTrackingAreas()

        let area = try XCTUnwrap(view.trackingAreas.first)
        XCTAssertTrue(area.options.contains(.mouseEnteredAndExited))
        XCTAssertTrue(area.options.contains(.activeAlways))
        XCTAssertTrue(area.options.contains(.inVisibleRect))
        XCTAssertTrue((area.owner as AnyObject?) === view)
    }
}
