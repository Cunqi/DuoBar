import SwiftUI
import DuoBarCore

extension AdaptiveRingColorPresentation {
    var color: Color? {
        guard role != .monochrome else { return nil }
        let base: Color
        switch role {
        case .monochrome: return nil
        case .cpu: base = .blue
        case .memory: base = .purple
        case .thermal: base = .orange
        }
        return base.opacity(intensity)
    }
}
