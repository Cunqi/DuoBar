import Foundation
import DuoBarCore

extension MenuBarIconSize {
    static let preferenceKey = "duoBar.menuBarIconScale"

    static func storedScale(in defaults: UserDefaults = .standard) -> Double {
        let rawValue = (defaults.object(forKey: preferenceKey) as? NSNumber)?.doubleValue
        return resolve(rawValue)
    }
}
