import XCTest
@testable import DuoBar

final class PopoverModulesTests: XCTestCase {
    func testDeviceListOnlyOffersDevicesForTheRequestedDirection() {
        let descriptors = [
            AudioDeviceDescriptor(id: 1, name: "Mac mini Speakers", hasOutput: true, hasInput: false),
            AudioDeviceDescriptor(id: 2, name: "Studio Display", hasOutput: true, hasInput: true),
            AudioDeviceDescriptor(id: 3, name: "USB Microphone", hasOutput: false, hasInput: true)
        ]

        let outputs = AudioDeviceOption.options(from: descriptors, direction: .output, defaultID: 2)
        let inputs = AudioDeviceOption.options(from: descriptors, direction: .input, defaultID: 3)

        XCTAssertEqual(outputs.map(\.name), ["Mac mini Speakers", "Studio Display"])
        XCTAssertEqual(outputs.map(\.isDefault), [false, true])
        XCTAssertEqual(inputs.map(\.name), ["Studio Display", "USB Microphone"])
        XCTAssertEqual(inputs.first(where: \.isDefault)?.id, 3)
    }

    func testDiskSpaceReportsUsedShareOfTheVolume() {
        let disk = DiskSpaceStatus(totalBytes: 500_000_000_000, availableBytes: 125_000_000_000)

        XCTAssertEqual(disk.usedFraction, 0.75, accuracy: 0.0001)
        XCTAssertEqual(disk.usedPercentage, 75)
        XCTAssertEqual(DiskSpaceStatus(totalBytes: 0, availableBytes: 0).usedFraction, 0)
    }
}
