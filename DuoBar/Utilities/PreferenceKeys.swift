enum PreferenceKeys {
    static let showBatteryPercentage = "showBatteryPercentage"
    static let animationsEnabled = "animationsEnabled"
    static let menuBarIconScale = MenuBarIconSize.preferenceKey
    static let batteryColorCoding = "batteryColorCoding"
    static let adaptiveRingPriority = "adaptiveRingPriority"
    static let adaptiveRingColorCoding = "adaptiveRingColorCoding"
    static let openOnHover = "duoBar.openOnHover"
    static let ringContent = "duoBar.ringContent"
    static let ringPressureOverride = "duoBar.ringPressureOverride"
    static let popoverLayout = "duoBar.popoverLayout"

    #if DEBUG
    static let simulateDesktopMac = "debug.simulateDesktopMac"
    #endif
}
