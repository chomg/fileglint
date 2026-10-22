// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Fileglint",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PreviewCore", targets: ["PreviewCore"]),
        .library(name: "PreviewOpening", targets: ["PreviewOpening"]),
        .library(name: "PreviewUI", targets: ["PreviewUI"]),
        .executable(name: "PreviewHost", targets: ["PreviewHost"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2"),
        .package(url: "https://github.com/LebJe/TOMLKit.git", exact: "0.6.0"),
    ],
    targets: [
        .target(name: "PreviewCore", dependencies: ["Yams", "TOMLKit"]),
        .target(name: "PreviewOpening"),
        .target(name: "PreviewUI", dependencies: ["PreviewCore", "PreviewOpening"]),
        .executableTarget(name: "PreviewHost", dependencies: ["PreviewUI", "PreviewCore"]),
        .target(name: "PreviewExtension", dependencies: ["PreviewCore", "PreviewUI"]),
        .testTarget(name: "PreviewOpeningTests", dependencies: ["PreviewOpening"]),
        .testTarget(name: "PreviewCoreTests", dependencies: ["PreviewCore", "Yams", "TOMLKit"]),
        .testTarget(name: "PreviewUITests", dependencies: ["PreviewUI", "PreviewCore", "PreviewOpening"]),
    ],
    swiftLanguageModes: [.v5]
)
