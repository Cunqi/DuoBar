import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class PopoverRenderTests: XCTestCase {
    @MainActor
    func testRenderFinalPopover() throws {
        let store = SystemStatusStore(startServices: false)
        store.applyDebugBatteryLevel(.full)
        store.applyDebugNetworkState(.strong)
        store.applyDebugAudioDeviceState(.builtIn)
        store.applyDebugVolumeState(.fiftyOne)

        let view = StatusPopoverView(statusStore: store, onClose: {})
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .dark)

        try writePNG(view, named: "DuoBar-1.0-Popover.png")
    }

    @MainActor
    func testRenderNativeMenuBarScaleComparison() throws {
        let status = DebugAudioDeviceState.builtIn.status
        let systemStatus = SystemStatus(
            battery: BatteryStatus(percentage: 75, isCharging: false, isPluggedIn: false, isFullyCharged: false, isAvailable: true),
            network: DebugNetworkState.strong.status,
            audio: status,
            bluetooth: .unavailable
        )

        let view = HStack(spacing: 11) {
            Image(systemName: "wifi")
            Image(systemName: "speaker.wave.2.fill")
            DuoGlyphView(status: systemStatus, animationsEnabled: false)
            Image(systemName: "battery.75percent")
        }
        .font(.system(size: 13, weight: .semibold))
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.black)

        try writePNG(view, named: "DuoBar-1.0-MenuBar-Comparison.png")
    }

    @MainActor
    private func writePNG<Content: View>(_ content: Content, named name: String) throws {
        let hostingView = NSHostingView(rootView: content)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
        hostingView.layoutSubtreeIfNeeded()
        let representation = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(name), options: .atomic)
        XCTAssertGreaterThan(png.count, 1_000)
    }
}
