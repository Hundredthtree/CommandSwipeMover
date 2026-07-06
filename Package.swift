// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CommandSwipeMover",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CommandSwipeMover", targets: ["CommandSwipeMover"])
    ],
    targets: [
        .executableTarget(
            name: "CommandSwipeMover",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
