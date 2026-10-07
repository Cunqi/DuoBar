import Foundation
import DuoBarCore

extension PerformancePreference {
    var localizedDisplayName: String {
        switch self {
        case .automatic: localized("Automatic")
        case .cpu: localized("Prefer CPU")
        case .memory: localized("Prefer Memory")
        case .thermal: localized("Prefer Thermal")
        }
    }
}
