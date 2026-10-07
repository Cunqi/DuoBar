import DuoBarCore
import DuoBarKit
import SwiftUI

struct DiskSpaceRow: View {
    @State private var disk = DiskSpaceReader.startupVolume()

    var body: some View {
        StatusRow(
            symbol: "internaldrive",
            title: localized("Disk Space"),
            detail: detail,
            stateText: disk.map { localized("%d%%", $0.usedPercentage) } ?? "",
            tint: .primary
        )
        .onAppear { disk = DiskSpaceReader.startupVolume() }
    }

    private var detail: String {
        guard let disk else { return localized("No data") }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return localized(
            "%@ available of %@",
            formatter.string(fromByteCount: disk.availableBytes),
            formatter.string(fromByteCount: disk.totalBytes)
        )
    }
}
