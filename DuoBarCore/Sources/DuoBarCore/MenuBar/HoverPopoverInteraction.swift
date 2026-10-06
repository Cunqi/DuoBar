import Foundation

public enum HoverPopoverPresentationState: Equatable {
    case closed
    case hoverOpen
    case pinned
}

public enum HoverPopoverCommand: Equatable {
    case open
    case close
    case scheduleClose
    case cancelClose
}

public struct HoverPopoverInteraction {
    public private(set) var state: HoverPopoverPresentationState = .closed
    public private(set) var isEnabled: Bool
    public private(set) var isPointerOverStatusItem = false
    public private(set) var isPointerOverPopover = false
    public private(set) var suppressHoverUntilStatusItemExit = false

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    public mutating func setEnabled(_ enabled: Bool) -> [HoverPopoverCommand] {
        guard enabled != isEnabled else { return [] }
        isEnabled = enabled

        guard !enabled else { return [] }
        suppressHoverUntilStatusItemExit = false
        guard state == .hoverOpen else { return [.cancelClose] }
        state = .closed
        return [.cancelClose, .close]
    }

    public mutating func statusItemEntered() -> [HoverPopoverCommand] {
        isPointerOverStatusItem = true
        guard isEnabled else { return [] }
        guard !suppressHoverUntilStatusItemExit else { return [.cancelClose] }

        if state == .closed {
            state = .hoverOpen
            return [.cancelClose, .open]
        }
        return [.cancelClose]
    }

    public mutating func statusItemExited() -> [HoverPopoverCommand] {
        isPointerOverStatusItem = false
        if suppressHoverUntilStatusItemExit {
            suppressHoverUntilStatusItemExit = false
        }
        return closeCommandsIfPointerIsOutside()
    }

    public mutating func popoverEntered() -> [HoverPopoverCommand] {
        isPointerOverPopover = true
        guard state == .hoverOpen else { return [] }
        return [.cancelClose]
    }

    public mutating func popoverExited() -> [HoverPopoverCommand] {
        isPointerOverPopover = false
        return closeCommandsIfPointerIsOutside()
    }

    public mutating func statusItemClicked() -> [HoverPopoverCommand] {
        switch state {
        case .closed:
            state = .pinned
            return [.cancelClose, .open]
        case .hoverOpen:
            state = .pinned
            return [.cancelClose]
        case .pinned:
            state = .closed
            suppressHoverUntilStatusItemExit = isEnabled && isPointerOverStatusItem
            return [.cancelClose, .close]
        }
    }

    public mutating func closeDelayElapsed() -> [HoverPopoverCommand] {
        guard state == .hoverOpen,
              !isPointerOverStatusItem,
              !isPointerOverPopover else {
            return []
        }
        state = .closed
        return [.close]
    }

    public mutating func applicationResignedActive() -> [HoverPopoverCommand] {
        closeCommandsIfPointerIsOutside()
    }

    public mutating func popoverClosedExternally() -> [HoverPopoverCommand] {
        state = .closed
        suppressHoverUntilStatusItemExit = isEnabled && isPointerOverStatusItem
        isPointerOverPopover = false
        return [.cancelClose]
    }

    private func closeCommandsIfPointerIsOutside() -> [HoverPopoverCommand] {
        guard isEnabled,
              state == .hoverOpen,
              !isPointerOverStatusItem,
              !isPointerOverPopover else {
            return []
        }
        return [.scheduleClose]
    }
}
