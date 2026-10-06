import DuoBarKit
import SwiftUI

struct KeepAwakeRow: View {
    @ObservedObject private var service = KeepAwakeService.shared

    var body: some View {
        StatusRow(
            symbol: service.isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer",
            title: localized("Keep Awake"),
            detail: service.isEnabled ? localized("Display and system won't sleep automatically") : localized("Off"),
            stateText: "",
            tint: .primary,
            trailing: AnyView(
                Toggle(localized("Keep Awake"), isOn: Binding(get: { service.isEnabled }, set: service.setEnabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            )
        )
    }
}
