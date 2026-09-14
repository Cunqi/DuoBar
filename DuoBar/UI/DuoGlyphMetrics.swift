import CoreGraphics

struct DuoGlyphMetrics: Equatable {
    static let standard = DuoGlyphMetrics(
        overallSize: 24,
        ringDiameter: 26.5,
        ringLineWidth: 2.8,
        arcGap: 110,
        wifiSymbolSize: 12.4,
        wifiYOffset: -1.25,
        dotDiameter: 2.9,
        dotSpacing: 1.8,
        dotYOffset: 11.2
    )

    static let canvasSize: CGFloat = 32

    var overallSize: CGFloat
    var ringDiameter: CGFloat
    var ringLineWidth: CGFloat
    var arcGap: Double
    var wifiSymbolSize: CGFloat
    var wifiYOffset: CGFloat
    var dotDiameter: CGFloat
    var dotSpacing: CGFloat
    var dotYOffset: CGFloat

    let ringYOffset: CGFloat = -0.8

    var arcStartDegrees: Double { 90 + arcGap / 2 }
    var arcEndDegrees: Double { 450 - arcGap / 2 }
    var statusItemWidth: CGFloat { overallSize + 3 }

    func sized(_ size: CGFloat) -> DuoGlyphMetrics {
        var copy = self
        copy.overallSize = size
        return copy
    }
}

#if DEBUG
enum DuoGlyphTuningKeys {
    static let overallSize = "debug.duoGlyph.overallSize"
    static let ringDiameter = "debug.duoGlyph.ringDiameter"
    static let ringLineWidth = "debug.duoGlyph.ringLineWidth"
    static let arcGap = "debug.duoGlyph.arcGap"
    static let wifiSymbolSize = "debug.duoGlyph.wifiSymbolSize"
    static let wifiYOffset = "debug.duoGlyph.wifiYOffset"
    static let dotDiameter = "debug.duoGlyph.dotDiameter"
    static let dotSpacing = "debug.duoGlyph.dotSpacing"
    static let dotYOffset = "debug.duoGlyph.dotYOffset"
}
#endif
