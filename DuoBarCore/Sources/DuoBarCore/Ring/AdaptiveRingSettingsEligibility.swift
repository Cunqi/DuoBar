import Foundation

public enum AdaptiveRingSettingsEligibility {
    public static func isEligible(for context: DeviceContext) -> Bool {
        context.ringBehavior == .adaptiveRing
    }

    #if DEBUG
    public static func isEligible(for context: DeviceContext, simulateDesktop: Bool) -> Bool {
        simulateDesktop || isEligible(for: context)
    }
    #endif
}
