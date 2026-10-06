// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DuoBarCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "DuoBarCore", targets: ["DuoBarCore"])],
    targets: [
        .target(name: "DuoBarCore"),
        .testTarget(name: "DuoBarCoreTests", dependencies: ["DuoBarCore"])
    ],
    swiftLanguageVersions: [.v5]
)
