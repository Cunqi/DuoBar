import CoreGraphics
import Foundation

enum DisplayBrightnessAvailability: Equatable, Sendable {
    case available(Double)
    case unavailable
}

struct MainDisplayDescriptor: Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let vendorID: UInt32
    let productID: UInt32
    let serialNumber: UInt32

    var diagnosticLabel: String {
        "Display \(displayID) · \(vendorID):\(productID)"
    }
}

struct DisplayBrightnessSnapshot: Equatable, Sendable {
    let mainDisplay: MainDisplayDescriptor
    let availability: DisplayBrightnessAvailability
    let sampledAt: TimeInterval

    func isFresh(at timestamp: TimeInterval, maximumAge: TimeInterval) -> Bool {
        timestamp >= sampledAt && timestamp - sampledAt <= maximumAge
    }
}

struct DisplayHardwareIdentity: Equatable, Sendable {
    let vendorID: UInt32
    let productID: UInt32
    let serialNumber: UInt32

    func matches(_ display: MainDisplayDescriptor) -> Bool {
        guard vendorID == display.vendorID, productID == display.productID else { return false }
        return display.serialNumber == 0 || serialNumber == 0 || serialNumber == display.serialNumber
    }

    static func uniqueMatchIndex(
        for display: MainDisplayDescriptor,
        candidates: [DisplayHardwareIdentity]
    ) -> Int? {
        let matches = candidates.indices.filter { candidates[$0].matches(display) }
        return matches.count == 1 ? matches[0] : nil
    }
}
