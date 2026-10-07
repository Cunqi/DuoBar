import SwiftUI

struct GeneralSettingsPane: View {
    @AppStorage(PreferenceKeys.openOnHover) private var openOnHover = false
    @StateObject private var launchAtLogin = LaunchAtLoginService()

    var body: some View {
        SettingsPaneForm {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(localized("Open on Hover"), isOn: $openOnHover)
                        .toggleStyle(.switch)
                    Text(localized("Open DuoBar when the pointer moves over the menu bar icon."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(
                    localized("Launch DuoBar at login"),
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: launchAtLogin.setEnabled
                    )
                )

                if launchAtLogin.requiresApproval {
                    Text(localized("Approval is required in System Settings → General → Login Items."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}
