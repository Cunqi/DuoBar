import SwiftUI

struct NetworkStatusSection: View {
    let symbol: String
    let symbolVariableValue: Double?
    let detail: String
    let stateText: String
    let currentSSID: String?
    let canBrowseNetworks: Bool
    let trailing: AnyView?

    @StateObject private var picker = WiFiNetworkPicker()
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if isExpanded, canBrowseNetworks {
                Divider()
                    .padding(.horizontal, 10)
                WiFiNetworkListView(picker: picker)
                    .padding(.vertical, 6)
            }
        }
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onChange(of: canBrowseNetworks) { canBrowse in
            if !canBrowse {
                isExpanded = false
            }
        }
        .onChange(of: currentSSID) { ssid in
            picker.updateCurrentSSID(ssid)
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            HStack(spacing: 11) {
                Image(systemName: symbol, variableValue: symbolVariableValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(localized("Network"))
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if canBrowseNetworks {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: toggleExpanded)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(canBrowseNetworks ? .isButton : [])
            .accessibilityHint(canBrowseNetworks ? localized("Show Wi-Fi networks") : "")

            if let trailing {
                trailing
            } else {
                Text(stateText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
    }

    private func toggleExpanded() {
        guard canBrowseNetworks else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            isExpanded.toggle()
        }
        if isExpanded {
            picker.scan(currentSSID: currentSSID)
        } else {
            picker.cancelPasswordPrompt()
        }
    }
}

private struct WiFiNetworkListView: View {
    @ObservedObject var picker: WiFiNetworkPicker

    private let rowHeight: CGFloat = 28
    private let maximumVisibleRows: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch picker.scanState {
            case .idle, .scanning:
                statusLine {
                    ProgressView()
                        .controlSize(.small)
                    Text(localized("Scanning for networks…"))
                }
            case .failed:
                statusLine { Text(localized("No networks found")) }
            case .loaded:
                if picker.options.isEmpty {
                    statusLine { Text(localized("No networks found")) }
                } else {
                    networkRows
                }
            }

            Divider()
                .padding(.horizontal, 10)
                .padding(.vertical, 2)

            Button(action: picker.openSystemSettings) {
                Text(localized("Wi-Fi Settings…"))
                    .font(.system(size: 11.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var networkRows: some View {
        let rows = VStack(spacing: 0) {
            ForEach(picker.options) { option in
                WiFiNetworkRow(option: option, picker: picker)
            }
        }
        if CGFloat(picker.options.count) > maximumVisibleRows {
            ScrollView {
                rows
            }
            .frame(height: rowHeight * maximumVisibleRows)
        } else {
            rows
        }
    }

    private func statusLine<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            content()
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: rowHeight)
    }
}

private struct WiFiNetworkRow: View {
    let option: WiFiNetworkOption
    @ObservedObject var picker: WiFiNetworkPicker
    @State private var password = ""
    @State private var isHovered = false
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            Button { picker.select(option) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wifi", variableValue: option.signalLevel.symbolVariableValue)
                        .font(.system(size: 11.5, weight: .semibold))
                        .frame(width: 16)
                    Text(option.ssid)
                        .font(.system(size: 11.5, weight: option.isCurrent ? .semibold : .regular))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    trailingIndicator
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                        .padding(.horizontal, 4)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(picker.joiningSSID != nil)
            .onHover { isHovered = $0 }
            .accessibilityValue(option.isCurrent ? localized("Connected") : "")

            if picker.passwordPromptSSID == option.ssid {
                passwordPrompt
            }

            if picker.failedSSID == option.ssid {
                Text(localized("Unable to join “%@”", option.ssid))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        if picker.joiningSSID == option.ssid {
            ProgressView()
                .controlSize(.mini)
        } else if option.isCurrent {
            Image(systemName: "checkmark")
                .font(.system(size: 10.5, weight: .semibold))
        } else if option.security != .open {
            Image(systemName: "lock.fill")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
    }

    private var passwordPrompt: some View {
        HStack(spacing: 6) {
            SecureField(localized("Password"), text: $password)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .focused($isPasswordFocused)
                .onSubmit(submit)
            Button(localized("Cancel")) {
                password = ""
                picker.cancelPasswordPrompt()
            }
            .controlSize(.small)
            Button(localized("Join"), action: submit)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty || picker.joiningSSID != nil)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
        .onAppear { isPasswordFocused = true }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        picker.submitPassword(password, for: option)
        password = ""
    }
}
