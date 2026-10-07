import Foundation

public enum MenuBarIconSize {
    public static let minimumScale = 0.80
    public static let defaultScale = 1.00
    public static let maximumScale = 1.05
    public static let step = 0.05
    public static let minimumStatusItemWidth: CGFloat = 22
    public static let baseStatusItemWidth: CGFloat = 27

    public static func resolve(_ rawValue: Double?) -> Double {
        guard let rawValue, rawValue.isFinite else { return defaultScale }

        let clamped = min(max(rawValue, minimumScale), maximumScale)
        let quantizedPercent = ((clamped * 100) / (step * 100)).rounded() * (step * 100)
        return min(max(quantizedPercent / 100, minimumScale), maximumScale)
    }


    public static func statusItemWidth(for rawScale: Double?) -> CGFloat {
        max(minimumStatusItemWidth, baseStatusItemWidth * CGFloat(resolve(rawScale)))
    }
}
