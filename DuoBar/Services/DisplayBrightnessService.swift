import CoreGraphics
import Foundation
import IOKit
import IOKit.graphics

protocol DisplayBrightnessReading {
    func readMainDisplay(at timestamp: TimeInterval) -> DisplayBrightnessSnapshot
}

struct DisplayBrightnessService: DisplayBrightnessReading {
    func readMainDisplay(at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DisplayBrightnessSnapshot {
        let mainDisplayID = CGDisplayPrimaryDisplay(CGMainDisplayID())
        let mainDisplay = MainDisplayDescriptor(
            displayID: mainDisplayID,
            vendorID: CGDisplayVendorNumber(mainDisplayID),
            productID: CGDisplayModelNumber(mainDisplayID),
            serialNumber: CGDisplaySerialNumber(mainDisplayID)
        )

        return DisplayBrightnessSnapshot(
            mainDisplay: mainDisplay,
            availability: readBrightness(for: mainDisplay),
            sampledAt: timestamp
        )
    }

    private func readBrightness(for mainDisplay: MainDisplayDescriptor) -> DisplayBrightnessAvailability {
        guard let matching = IOServiceMatching("IOFramebuffer") else { return .unavailable }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return .unavailable
        }
        defer { IOObjectRelease(iterator) }

        var candidates: [Candidate] = []
        var framebuffer = IOIteratorNext(iterator)
        while framebuffer != 0 {
            if let candidate = candidate(for: framebuffer) {
                candidates.append(candidate)
            }
            IOObjectRelease(framebuffer)
            framebuffer = IOIteratorNext(iterator)
        }

        // Identical displays without usable serials cannot be safely associated with
        // CGMainDisplayID. Failing closed avoids showing another monitor's brightness.
        guard let matchIndex = DisplayHardwareIdentity.uniqueMatchIndex(
            for: mainDisplay,
            candidates: candidates.map(\.identity)
        ), let value = candidates[matchIndex].brightness else {
            return .unavailable
        }
        return Self.validatedBrightness(value)
    }

    static func validatedBrightness(_ value: Double) -> DisplayBrightnessAvailability {
        guard value.isFinite, (0...1).contains(value) else { return .unavailable }
        return .available(value)
    }

    private func candidate(for framebuffer: io_service_t) -> Candidate? {
        let info = IODisplayCreateInfoDictionary(
            framebuffer,
            IOOptionBits(kIODisplayMatchingInfo)
        ).takeRetainedValue() as NSDictionary

        guard let vendorID = number(in: info, key: kDisplayVendorID),
              let productID = number(in: info, key: kDisplayProductID)
        else { return nil }

        let identity = DisplayHardwareIdentity(
            vendorID: vendorID,
            productID: productID,
            serialNumber: number(in: info, key: kDisplaySerialNumber) ?? 0
        )
        let displayService = IODisplayForFramebuffer(framebuffer, 0)
        guard displayService != 0 else { return Candidate(identity: identity, brightness: nil) }
        defer { IOObjectRelease(displayService) }

        var rawValue: Float = 0
        let result = IODisplayGetFloatParameter(
            displayService,
            0,
            kIODisplayBrightnessKey as CFString,
            &rawValue
        )
        let value = result == kIOReturnSuccess ? Double(rawValue) : nil
        return Candidate(identity: identity, brightness: value)
    }

    private func number(in dictionary: NSDictionary, key: String) -> UInt32? {
        (dictionary[key] as? NSNumber)?.uint32Value
    }

    private struct Candidate {
        let identity: DisplayHardwareIdentity
        let brightness: Double?
    }
}
