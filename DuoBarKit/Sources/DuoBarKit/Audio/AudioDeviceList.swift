import SwiftUI

public struct AudioDeviceListOption: Identifiable, Equatable, Sendable {
    public let id: UInt32
    public let name: String
    public let isDefault: Bool

    public init(id: UInt32, name: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

public struct AudioDeviceList: View {
    let options: [AudioDeviceListOption]
    let onSelect: (AudioDeviceListOption) -> Void

    public init(options: [AudioDeviceListOption], onSelect: @escaping (AudioDeviceListOption) -> Void) {
        self.options = options
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(options) { option in
                AudioDeviceListRow(option: option) { onSelect(option) }
            }
        }
    }
}

private struct AudioDeviceListRow: View {
    let option: AudioDeviceListOption
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(option.name)
                    .font(.system(size: 11.5, weight: option.isDefault ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if option.isDefault {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10.5, weight: .semibold))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    .padding(.horizontal, 4)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(option.isDefault ? .isSelected : [])
    }
}
