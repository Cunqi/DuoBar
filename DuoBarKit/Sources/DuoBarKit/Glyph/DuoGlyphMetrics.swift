import CoreGraphics

public struct DuoGlyphMetrics: Equatable {
    public static let standard = DuoGlyphMetrics(
        overallSize: 24,
        ringDiameter: 26.5,
        ringLineWidth: 2.8,
        arcGap: 120.2,
        wifiSymbolSize: 12.4,
        wifiYOffset: -1.25,
        dotDiameter: 2.477173913,
        dotSpacing: 1.766666667,
        dotYOffset: 7.495652174
    )

    public static let canvasSize: CGFloat = 32
    public static let menuBarVerticalOffset: CGFloat = 1
    public static let referenceArcStrokeRatio: CGFloat = 18 / 230
    private static let priorArcStrokeRatio: CGFloat = 2.8 / 26.5

    public var overallSize: CGFloat
    public var ringDiameter: CGFloat
    public var ringLineWidth: CGFloat
    public var arcGap: Double
    public var wifiSymbolSize: CGFloat
    public var wifiYOffset: CGFloat
    public var dotDiameter: CGFloat
    public var dotSpacing: CGFloat
    public var dotYOffset: CGFloat

    public var ringYOffset: CGFloat = -0.8
    public var statusItemHorizontalPadding: CGFloat = 3

    public init(
        overallSize: CGFloat,
        ringDiameter: CGFloat,
        ringLineWidth: CGFloat,
        arcGap: Double,
        wifiSymbolSize: CGFloat,
        wifiYOffset: CGFloat,
        dotDiameter: CGFloat,
        dotSpacing: CGFloat,
        dotYOffset: CGFloat,
        ringYOffset: CGFloat = -0.8,
        statusItemHorizontalPadding: CGFloat = 3
    ) {
        self.overallSize = overallSize
        self.ringDiameter = ringDiameter
        self.ringLineWidth = ringLineWidth
        self.arcGap = arcGap
        self.wifiSymbolSize = wifiSymbolSize
        self.wifiYOffset = wifiYOffset
        self.dotDiameter = dotDiameter
        self.dotSpacing = dotSpacing
        self.dotYOffset = dotYOffset
        self.ringYOffset = ringYOffset
        self.statusItemHorizontalPadding = statusItemHorizontalPadding
    }

    public var arcLineWidth: CGFloat {
        ringLineWidth * Self.referenceArcStrokeRatio / Self.priorArcStrokeRatio
    }
    public var ringPathDiameter: CGFloat { max(0, ringDiameter - arcLineWidth) }
    public var arcStartDegrees: Double { 90 + arcGap / 2 }
    public var arcEndDegrees: Double { 450 - arcGap / 2 }
    public var statusItemWidth: CGFloat {
        max(22, overallSize + statusItemHorizontalPadding)
    }

    public func sized(_ size: CGFloat) -> DuoGlyphMetrics {
        var copy = self
        copy.overallSize = size
        return copy
    }

    public func scaled(by rawScale: Double) -> DuoGlyphMetrics {
        let scale = CGFloat(rawScale)
        var copy = self
        copy.overallSize *= scale
        copy.ringDiameter *= scale
        copy.ringLineWidth *= scale
        copy.wifiSymbolSize *= scale
        copy.wifiYOffset *= scale
        copy.dotDiameter *= scale
        copy.dotSpacing *= scale
        copy.dotYOffset *= scale
        copy.ringYOffset *= scale
        copy.statusItemHorizontalPadding *= scale
        return copy
    }
}
