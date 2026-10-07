import SwiftUI

public struct PopoverCard<Header: View, Expanded: View>: View {
    let canExpand: Bool
    let header: Header
    let expanded: Expanded

    @State private var isExpanded = false

    public init(canExpand: Bool, @ViewBuilder header: () -> Header, @ViewBuilder expanded: () -> Expanded) {
        self.canExpand = canExpand
        self.header = header()
        self.expanded = expanded()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                header
                if canExpand {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .onTapGesture {
                guard canExpand else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded, canExpand {
                Divider()
                    .padding(.horizontal, 10)
                expanded
                    .padding(.vertical, 6)
            }
        }
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
