// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WarpConfigurator",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WarpConfigurator",
            path: "Sources/WarpConfigurator"
        )
    ]
)
