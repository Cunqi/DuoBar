public enum DisplayBrightnessResolver {
    public static func validatedBrightness(_ value: Double) -> DisplayBrightnessAvailability {
        guard value.isFinite, (0...1).contains(value) else { return .unavailable }
        return .available(value)
    }

    public static func resolvedBrightness(standard: Double?, linearFallback: Double?) -> DisplayBrightnessAvailability {
        for candidate in [standard, linearFallback] {
            guard let candidate else { continue }
            if case .available = validatedBrightness(candidate) {
                return validatedBrightness(candidate)
            }
        }
        return .unavailable
    }
}
