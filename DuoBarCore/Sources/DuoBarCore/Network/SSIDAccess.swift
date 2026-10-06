import Foundation


public enum SSIDAuthorizationState: String, Equatable, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined


    #if DEBUG
    public var diagnosticLabel: String {
        switch self {
        case .authorized: "Authorized"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not Determined"
        }
    }
    #endif
}

public enum LocationRequestTrigger: String, Equatable, Sendable {
    case startup
    case appBecameActive
    case popoverOpened
    case settingsOpened
    case none

    #if DEBUG
    public var diagnosticLabel: String {
        switch self {
        case .startup: "startup"
        case .appBecameActive: "app became active"
        case .popoverOpened: "popover opened"
        case .settingsOpened: "settings opened"
        case .none: "none"
        }
    }
    #endif
}

public enum SSIDAccessAction: Equatable {
    case requestAuthorization(trigger: LocationRequestTrigger)
    case refresh
}

public struct SSIDAccessCoordinator {
    public init() {}

    public private(set) var isWaitingForApplicationActivation = false
    public private(set) var hasAttemptedAuthorizationRequest = false
    public private(set) var hasIssuedAuthorizationRequest = false
    public private(set) var wasAuthorizationRequestIssuedWhileActive = false
    public private(set) var lastRequestTrigger: LocationRequestTrigger = .none

    public mutating func requestAccess(
        authorization: SSIDAuthorizationState,
        applicationIsActive: Bool,
        trigger: LocationRequestTrigger
    ) -> [SSIDAccessAction] {
        switch authorization {
        case .authorized, .denied, .restricted:
            isWaitingForApplicationActivation = false
            return [.refresh]
        case .notDetermined:
            guard !hasIssuedAuthorizationRequest else { return [] }
            hasAttemptedAuthorizationRequest = true
            lastRequestTrigger = trigger
            guard applicationIsActive else {
                isWaitingForApplicationActivation = true
                return []
            }
            isWaitingForApplicationActivation = false
            hasIssuedAuthorizationRequest = true
            wasAuthorizationRequestIssuedWhileActive = true
            return [.requestAuthorization(trigger: trigger)]
        }
    }

    public mutating func applicationDidBecomeActive(
        authorization: SSIDAuthorizationState
    ) -> [SSIDAccessAction] {
        guard isWaitingForApplicationActivation else { return [] }
        return requestAccess(
            authorization: authorization,
            applicationIsActive: true,
            trigger: .appBecameActive
        )
    }

    public mutating func authorizationDidChange(
        to authorization: SSIDAuthorizationState
    ) -> [SSIDAccessAction] {
        if authorization != .notDetermined {
            isWaitingForApplicationActivation = false
            hasIssuedAuthorizationRequest = false
        }
        return [.refresh]
    }
}

public enum SSIDValue {
    public static func normalized(_ rawValue: String?) -> String? {
        let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

public enum NetworkRefreshReason: String, Sendable {
    case startup
    case pathChange
    case authorizationChange
    case wifiPowerChange
    case periodic
    case manual

    #if DEBUG
    public var diagnosticLabel: String {
        switch self {
        case .startup: "startup"
        case .pathChange: "path change"
        case .authorizationChange: "authorization change"
        case .wifiPowerChange: "Wi-Fi power change"
        case .periodic: "periodic"
        case .manual: "manual"
        }
    }
    #endif
}
