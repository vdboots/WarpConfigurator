// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WarpConfigurator",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WarpConfigurator",
            path: "Sources/WarpConfigurator",
            resources: [.process("Resources")]
        )
    ]
)
