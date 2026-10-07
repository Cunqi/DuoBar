import Foundation

public enum DisplayBrightnessAvailability: Equatable, Sendable {
    case available(Double)
    case unavailable
}

public struct MainDisplayDescriptor: Equatable, Sendable {
    public init(
        displayID: UInt32,
        vendorID: UInt32,
        productID: UInt32,
        serialNumber: UInt32
    ) {
        self.displayID = displayID
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
    }

    public let displayID: UInt32
    public let vendorID: UInt32
    public let productID: UInt32
    public let serialNumber: UInt32

    public var diagnosticLabel: String {
        "Display \(displayID) · \(vendorID):\(productID)"
    }
}

public struct DisplayBrightnessSnapshot: Equatable, Sendable {
    public let mainDisplay: MainDisplayDescriptor
    public let availability: DisplayBrightnessAvailability
    public let sampledAt: TimeInterval

    #if DEBUG
    /// DEBUG-only evidence for the public IOKit brightness-read pipeline.
    /// It never changes `availability`.
    public let diagnostic: DisplayBrightnessDiagnostic?
    #endif

    #if DEBUG
    public init(
        mainDisplay: MainDisplayDescriptor,
        availability: DisplayBrightnessAvailability,
        sampledAt: TimeInterval,
        diagnostic: DisplayBrightnessDiagnostic? = nil
    ) {
        self.mainDisplay = mainDisplay
        self.availability = availability
        self.sampledAt = sampledAt
        self.diagnostic = diagnostic
    }
    #else
    public init(
        mainDisplay: MainDisplayDescriptor,
        availability: DisplayBrightnessAvailability,
        sampledAt: TimeInterval
    ) {
        self.mainDisplay = mainDisplay
        self.availability = availability
        self.sampledAt = sampledAt
    }
    #endif

    public func isFresh(at timestamp: TimeInterval, maximumAge: TimeInterval) -> Bool {
        timestamp >= sampledAt && timestamp - sampledAt <= maximumAge
    }
}

#if DEBUG
public enum DisplayBrightnessSource: String, Equatable, Sendable {
    case standard
    case linear
    case unavailable
}

public enum DisplayBrightnessFailureStage: String, Equatable, Sendable {
    case mainDisplayMetadata
    case framebufferEnumeration
    case displayIdentityMatch
    case ambiguousDisplayMatch
    case displayServiceResolution
    case standardBrightnessRead
    case linearBrightnessRead
    case invalidBrightnessValue
    case none
}

public enum DisplayBrightnessIdentitySelection: String, Equatable, Sendable {
    case uniqueMatch
    case ambiguousMatch
    case noMatch
}

public struct DisplayBrightnessParameterDiagnostic: Equatable, Sendable {
    public init(
        attempted: Bool,
        ioReturn: Int32?,
        value: Double?,
        isValid: Bool
    ) {
        self.attempted = attempted
        self.ioReturn = ioReturn
        self.value = value
        self.isValid = isValid
    }

    public let attempted: Bool
    public let ioReturn: Int32?
    public let value: Double?
    public let isValid: Bool

    public static let notAttempted = DisplayBrightnessParameterDiagnostic(
        attempted: false,
        ioReturn: nil,
        value: nil,
        isValid: false
    )

    public var reportValue: String {
        guard attempted else { return "not attempted" }
        let result = ioReturn.map { String(format: "0x%08X", UInt32(bitPattern: $0)) } ?? "none"
        let valueText = value.map { String(format: "%.4f", $0) } ?? "none"
        return "IOReturn \(result) · value \(valueText) · valid \(isValid ? "yes" : "no")"
    }
}

public struct DisplayBrightnessFramebufferDiagnostic: Equatable, Sendable {
    public init(
        index: Int,
        vendorID: UInt32?,
        productID: UInt32?,
        serialNumber: UInt32?,
        metadataReadable: Bool,
        displayServiceResolved: Bool?,
        standardBrightness: DisplayBrightnessParameterDiagnostic,
        linearBrightness: DisplayBrightnessParameterDiagnostic
    ) {
        self.index = index
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.metadataReadable = metadataReadable
        self.displayServiceResolved = displayServiceResolved
        self.standardBrightness = standardBrightness
        self.linearBrightness = linearBrightness
    }

    public let index: Int
    public let vendorID: UInt32?
    public let productID: UInt32?
    public let serialNumber: UInt32?
    public let metadataReadable: Bool
    public let displayServiceResolved: Bool?
    public let standardBrightness: DisplayBrightnessParameterDiagnostic
    public let linearBrightness: DisplayBrightnessParameterDiagnostic
}

public struct DisplayBrightnessDiagnostic: Equatable, Sendable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.mainDisplay == rhs.mainDisplay
            && lhs.isBuiltIn == rhs.isBuiltIn
            && lhs.bounds.origin.x == rhs.bounds.origin.x
            && lhs.bounds.origin.y == rhs.bounds.origin.y
            && lhs.bounds.size.width == rhs.bounds.size.width
            && lhs.bounds.size.height == rhs.bounds.size.height
            && lhs.framebufferCount == rhs.framebufferCount
            && lhs.framebufferCandidates == rhs.framebufferCandidates
            && lhs.vendorMatchCount == rhs.vendorMatchCount
            && lhs.vendorProductMatchCount == rhs.vendorProductMatchCount
            && lhs.vendorProductSerialMatchCount == rhs.vendorProductSerialMatchCount
            && lhs.selection == rhs.selection
            && lhs.identityFieldsUsed == rhs.identityFieldsUsed
            && lhs.selectedFramebufferIndex == rhs.selectedFramebufferIndex
            && lhs.displayServiceResolved == rhs.displayServiceResolved
            && lhs.standardBrightness == rhs.standardBrightness
            && lhs.linearBrightness == rhs.linearBrightness
            && lhs.source == rhs.source
            && lhs.value == rhs.value
            && lhs.failureStage == rhs.failureStage
    }

    public init(
        mainDisplay: MainDisplayDescriptor,
        isBuiltIn: Bool,
        bounds: CGRect,
        framebufferCount: Int,
        framebufferCandidates: [DisplayBrightnessFramebufferDiagnostic],
        vendorMatchCount: Int,
        vendorProductMatchCount: Int,
        vendorProductSerialMatchCount: Int?,
        selection: DisplayBrightnessIdentitySelection,
        identityFieldsUsed: String,
        selectedFramebufferIndex: Int?,
        displayServiceResolved: Bool?,
        standardBrightness: DisplayBrightnessParameterDiagnostic,
        linearBrightness: DisplayBrightnessParameterDiagnostic,
        source: DisplayBrightnessSource,
        value: Double?,
        failureStage: DisplayBrightnessFailureStage
    ) {
        self.mainDisplay = mainDisplay
        self.isBuiltIn = isBuiltIn
        self.bounds = bounds
        self.framebufferCount = framebufferCount
        self.framebufferCandidates = framebufferCandidates
        self.vendorMatchCount = vendorMatchCount
        self.vendorProductMatchCount = vendorProductMatchCount
        self.vendorProductSerialMatchCount = vendorProductSerialMatchCount
        self.selection = selection
        self.identityFieldsUsed = identityFieldsUsed
        self.selectedFramebufferIndex = selectedFramebufferIndex
        self.displayServiceResolved = displayServiceResolved
        self.standardBrightness = standardBrightness
        self.linearBrightness = linearBrightness
        self.source = source
        self.value = value
        self.failureStage = failureStage
    }

    public let mainDisplay: MainDisplayDescriptor
    public let isBuiltIn: Bool
    public let bounds: CGRect
    public let framebufferCount: Int
    public let framebufferCandidates: [DisplayBrightnessFramebufferDiagnostic]
    public let vendorMatchCount: Int
    public let vendorProductMatchCount: Int
    public let vendorProductSerialMatchCount: Int?
    public let selection: DisplayBrightnessIdentitySelection
    public let identityFieldsUsed: String
    public let selectedFramebufferIndex: Int?
    public let displayServiceResolved: Bool?
    public let standardBrightness: DisplayBrightnessParameterDiagnostic
    public let linearBrightness: DisplayBrightnessParameterDiagnostic
    public let source: DisplayBrightnessSource
    public let value: Double?
    public let failureStage: DisplayBrightnessFailureStage

    public static func classifyFailure(
        framebufferCount: Int,
        mainDisplayMetadataIsUsable: Bool,
        selection: DisplayBrightnessIdentitySelection,
        displayServiceResolved: Bool?,
        standardBrightness: DisplayBrightnessParameterDiagnostic,
        linearBrightness: DisplayBrightnessParameterDiagnostic
    ) -> DisplayBrightnessFailureStage {
        guard framebufferCount > 0 else { return .framebufferEnumeration }
        guard mainDisplayMetadataIsUsable else { return .mainDisplayMetadata }
        switch selection {
        case .noMatch: return .displayIdentityMatch
        case .ambiguousMatch: return .ambiguousDisplayMatch
        case .uniqueMatch: break
        }
        guard displayServiceResolved == true else { return .displayServiceResolution }
        if (standardBrightness.attempted && standardBrightness.ioReturn == 0 && !standardBrightness.isValid)
            || (linearBrightness.attempted && linearBrightness.ioReturn == 0 && !linearBrightness.isValid) {
            return .invalidBrightnessValue
        }
        if standardBrightness.attempted && standardBrightness.ioReturn != 0 {
            return .standardBrightnessRead
        }
        return .linearBrightnessRead
    }

    public static func resolvedSource(
        availability: DisplayBrightnessAvailability,
        standardBrightness: DisplayBrightnessParameterDiagnostic,
        linearBrightness: DisplayBrightnessParameterDiagnostic
    ) -> DisplayBrightnessSource {
        guard case .available = availability else { return .unavailable }
        return standardBrightness.isValid ? .standard : linearBrightness.isValid ? .linear : .unavailable
    }

    public var copyableReport: String {
        let serialUsable = mainDisplay.serialNumber != 0
        let boundsText = String(
            format: "%.0f×%.0f at %.0f,%.0f",
            bounds.size.width,
            bounds.size.height,
            bounds.origin.x,
            bounds.origin.y
        )
        let serialMatches = vendorProductSerialMatchCount.map(String.init) ?? "not usable"
        let candidateLines = framebufferCandidates.map { candidate in
            let vendor = candidate.vendorID.map(String.init) ?? "unavailable"
            let product = candidate.productID.map(String.init) ?? "unavailable"
            let serial = candidate.serialNumber.map(String.init) ?? "unavailable"
            return "  [\(candidate.index)] metadata \(candidate.metadataReadable ? "yes" : "no") · vendor \(vendor) · product \(product) · serial \(serial)"
        }.joined(separator: "\n")

        return """
        Main display
        Built-in: \(isBuiltIn ? "Yes" : "No") · ID: \(mainDisplay.displayID)
        Vendor: \(mainDisplay.vendorID) · Product: \(mainDisplay.productID) · Serial: \(mainDisplay.serialNumber) · Serial usable: \(serialUsable ? "Yes" : "No")
        Bounds: \(boundsText)

        IOFramebuffer candidates: \(framebufferCount)
        \(candidateLines.isEmpty ? "  none" : candidateLines)

        Identity match
        Vendor: \(vendorMatchCount) · Vendor + Product: \(vendorProductMatchCount) · Vendor + Product + Serial: \(serialMatches)
        Result: \(selection.rawValue) · Fields used: \(identityFieldsUsed) · Selected framebuffer: \(selectedFramebufferIndex.map(String.init) ?? "none")

        IODisplayForFramebuffer: \(displayServiceResolved == true ? "Success" : displayServiceResolved == false ? "Failure" : "not attempted")
        brightness: \(standardBrightness.reportValue)
        linear-brightness: \(linearBrightness.reportValue)

        Final: \(source.rawValue)\(value.map { String(format: " · %.4f", $0) } ?? "")
        Failure stage: \(failureStage.rawValue)
        """
    }
}
#endif

public struct DisplayHardwareIdentity: Equatable, Sendable {
    public init(
        vendorID: UInt32,
        productID: UInt32,
        serialNumber: UInt32
    ) {
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
    }

    public let vendorID: UInt32
    public let productID: UInt32
    public let serialNumber: UInt32

    public func matches(_ display: MainDisplayDescriptor) -> Bool {
        guard vendorID == display.vendorID, productID == display.productID else { return false }
        return display.serialNumber == 0 || serialNumber == 0 || serialNumber == display.serialNumber
    }

    public static func uniqueMatchIndex(
        for display: MainDisplayDescriptor,
        candidates: [DisplayHardwareIdentity]
    ) -> Int? {
        let matches = candidates.indices.filter { candidates[$0].matches(display) }
        return matches.count == 1 ? matches[0] : nil
    }
}
