public enum WiFiPowerControlResult: Equatable, Sendable {
    case success(actualPowerState: Bool)
    case unavailable
    case failure(actualPowerState: Bool?, message: String)
}
