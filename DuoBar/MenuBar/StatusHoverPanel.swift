import AppKit
import SwiftUI

@MainActor
final class StatusHoverPanel {
    private static let showDelay: TimeInterval = 0.6
    private static let verticalGap: CGFloat = 4

    private let model = StatusHoverPanelModel()
    private var panel: NSPanel?
    private var pendingShow: DispatchWorkItem?

    var isVisible: Bool { panel?.isVisible == true }

    func update(text: String) {
        model.text = text
        if isVisible {
            resizeAndPosition()
        }
    }

    func scheduleShow(below anchor: @escaping () -> NSRect?) {
        cancelPendingShow()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let frame = anchor() else { return }
            self.show(below: frame)
        }
        pendingShow = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.showDelay, execute: work)
    }

    func hide() {
        cancelPendingShow()
        panel?.orderOut(nil)
    }

    private var anchorFrame: NSRect?

    private func cancelPendingShow() {
        pendingShow?.cancel()
        pendingShow = nil
    }

    private func show(below frame: NSRect) {
        anchorFrame = frame
        let panel = panel ?? makePanel()
        self.panel = panel
        resizeAndPosition()
        panel.orderFrontRegardless()
    }

    private func resizeAndPosition() {
        guard let panel, let anchorFrame, let contentView = panel.contentView else { return }
        let size = contentView.fittingSize
        var origin = NSPoint(
            x: anchorFrame.midX - size.width / 2,
            y: anchorFrame.minY - Self.verticalGap - size.height
        )
        if let visible = NSScreen.screens.first(where: { $0.frame.intersects(anchorFrame) })?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 4), visible.maxX - size.width - 4)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: StatusHoverPanelView(model: model))
        return panel
    }
}

@MainActor
private final class StatusHoverPanelModel: ObservableObject {
    @Published var text = ""
}

private struct StatusHoverPanelView: View {
    @ObservedObject var model: StatusHoverPanelModel

    var body: some View {
        Text(model.text)
            .font(.system(size: 11.5))
            .monospacedDigit()
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08))
            )
    }
}
