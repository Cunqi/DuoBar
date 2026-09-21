import Foundation
import IOKit.pwr_mgt

@MainActor
final class KeepAwakeService: ObservableObject {
    static let shared = KeepAwakeService()

    @Published private(set) var isEnabled = false

    private var assertionID = IOPMAssertionID(0)

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        if enabled {
            var assertion = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "DuoBar Keep Awake" as CFString,
                &assertion
            )
            guard result == kIOReturnSuccess else { return }
            assertionID = assertion
            isEnabled = true
        } else {
            IOPMAssertionRelease(assertionID)
            assertionID = IOPMAssertionID(0)
            isEnabled = false
        }
    }
}
