import XCTest
@testable import DuoBarCore

final class HoverPopoverInteractionTests: XCTestCase {
    func testEnablingTakesEffectImmediately() {
        var interaction = HoverPopoverInteraction(isEnabled: false)

        XCTAssertEqual(interaction.setEnabled(true), [])
        XCTAssertEqual(interaction.statusItemEntered(), [.cancelClose, .open])
        XCTAssertEqual(interaction.state, .hoverOpen)
    }


    func testDisabledHoverDoesNothingAndClickBehaviorIsPreserved() {
        var interaction = HoverPopoverInteraction()
        XCTAssertEqual(interaction.statusItemEntered(), [])
        XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose, .open])
        XCTAssertEqual(interaction.state, .pinned)
        XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose, .close])
        XCTAssertEqual(interaction.state, .closed)
    }

    func testHoverEnterOpensOnlyOnceWhenEnabled() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        XCTAssertEqual(interaction.statusItemEntered(), [.cancelClose, .open])
        XCTAssertEqual(interaction.statusItemEntered(), [.cancelClose])
        XCTAssertEqual(interaction.state, .hoverOpen)
    }

    func testLeaveSchedulesAndReenterCancelsClose() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        XCTAssertEqual(interaction.statusItemExited(), [.scheduleClose])
        XCTAssertEqual(interaction.statusItemEntered(), [.cancelClose])
        XCTAssertEqual(interaction.closeDelayElapsed(), [])
        XCTAssertEqual(interaction.state, .hoverOpen)
    }

    func testStatusItemToPopoverTransitionCancelsPendingClose() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        XCTAssertEqual(interaction.statusItemExited(), [.scheduleClose])
        XCTAssertEqual(interaction.popoverEntered(), [.cancelClose])
        XCTAssertEqual(interaction.closeDelayElapsed(), [])
        XCTAssertEqual(interaction.state, .hoverOpen)
    }

    func testPopoverToStatusItemTransitionStaysOpen() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        _ = interaction.popoverEntered()
        XCTAssertEqual(interaction.popoverExited(), [])
        XCTAssertEqual(interaction.statusItemEntered(), [.cancelClose])
        XCTAssertEqual(interaction.state, .hoverOpen)
    }

    func testLeavingBothClosesWhenDelayFires() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        _ = interaction.statusItemExited()
        XCTAssertEqual(interaction.closeDelayElapsed(), [.close])
        XCTAssertEqual(interaction.state, .closed)
    }

    func testHoverOpenClickPinsAndDelayedCloseCannotClosePinned() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose])
        XCTAssertEqual(interaction.state, .pinned)
        _ = interaction.statusItemExited()
        XCTAssertEqual(interaction.closeDelayElapsed(), [])
        XCTAssertEqual(interaction.state, .pinned)
    }

    func testClosedClickPinsAndPinnedClickCloses() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose, .open])
        XCTAssertEqual(interaction.state, .pinned)
        XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose, .close])
        XCTAssertEqual(interaction.state, .closed)
    }

    func testExplicitCloseRequiresLeaveBeforeHoverCanReopen() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        _ = interaction.statusItemClicked()
        _ = interaction.statusItemClicked()
        XCTAssertTrue(interaction.suppressHoverUntilStatusItemExit)
        XCTAssertEqual(interaction.statusItemEntered(), [.cancelClose])
        _ = interaction.statusItemExited()
        XCTAssertFalse(interaction.suppressHoverUntilStatusItemExit)
        XCTAssertEqual(interaction.statusItemEntered(), [.cancelClose, .open])
    }

    func testDisablingClosesHoverOpenButPreservesPinned() {
        var hoverOpen = HoverPopoverInteraction(isEnabled: true)
        _ = hoverOpen.statusItemEntered()
        XCTAssertEqual(hoverOpen.setEnabled(false), [.cancelClose, .close])
        XCTAssertEqual(hoverOpen.state, .closed)

        var pinned = HoverPopoverInteraction(isEnabled: true)
        _ = pinned.statusItemClicked()
        XCTAssertEqual(pinned.setEnabled(false), [.cancelClose])
        XCTAssertEqual(pinned.state, .pinned)
    }

    func testExternalCloseResetsStateAndSuppressesImmediateReopen() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        XCTAssertEqual(interaction.popoverClosedExternally(), [.cancelClose])
        XCTAssertEqual(interaction.state, .closed)
        XCTAssertTrue(interaction.suppressHoverUntilStatusItemExit)
        XCTAssertEqual(interaction.statusItemEntered(), [.cancelClose])
    }

    func testApplicationResignCannotBypassCombinedHoverDelay() {
        var hoverOpen = HoverPopoverInteraction(isEnabled: true)
        _ = hoverOpen.statusItemEntered()
        XCTAssertEqual(hoverOpen.statusItemExited(), [.scheduleClose])
        XCTAssertEqual(hoverOpen.applicationResignedActive(), [.scheduleClose])
        XCTAssertEqual(hoverOpen.state, .hoverOpen)

        XCTAssertEqual(hoverOpen.popoverEntered(), [.cancelClose])
        XCTAssertEqual(hoverOpen.applicationResignedActive(), [])
        XCTAssertEqual(hoverOpen.closeDelayElapsed(), [])
        XCTAssertEqual(hoverOpen.state, .hoverOpen)

        var pinned = HoverPopoverInteraction(isEnabled: true)
        _ = pinned.statusItemClicked()
        XCTAssertEqual(pinned.applicationResignedActive(), [])
        XCTAssertEqual(pinned.state, .pinned)
    }

}
