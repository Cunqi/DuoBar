import SwiftUI

enum SettingsPane: String, Hashable, Identifiable {
    case general
    case menuBar
    case popover
    #if DEBUG
    case debugDiagnostics
    case debugGlyphTuning
    #endif

    var id: Self { self }

    var title: String {
        switch self {
        case .general: localized("General")
        case .menuBar: localized("Menu Bar Icon")
        case .popover: localized("Popover")
        #if DEBUG
        case .debugDiagnostics: "Diagnostics"
        case .debugGlyphTuning: "Glyph Tuning"
        #endif
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .popover: "list.bullet.rectangle"
        #if DEBUG
        case .debugDiagnostics: "stethoscope"
        case .debugGlyphTuning: "slider.horizontal.3"
        #endif
        }
    }
}

struct SettingsSidebar: View {
    let panes: [SettingsPane]
    let selection: SettingsPane
    let select: (SettingsPane) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(panes) { pane in
                SettingsSidebarRow(pane: pane, isSelected: pane == selection) {
                    select(pane)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SettingsSidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(pane.title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: pane.symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 18)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SettingsPaneForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
    }
}
