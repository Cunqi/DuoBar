// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DuoBarKit",
    platforms: [.macOS(.v13)],
    products: [.library(name: "DuoBarKit", targets: ["DuoBarKit"])],
    targets: [.target(name: "DuoBarKit")],
    swiftLanguageVersions: [.v5]
)
