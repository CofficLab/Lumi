// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderDeveloperMode",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderDeveloperMode",
            targets: ["ProviderDeveloperMode"]
        ),
    ],
    targets: [
        .target(
            name: "ProviderDeveloperMode",
            path: "Sources/ProviderDeveloperMode"
        ),
        .testTarget(
            name: "ProviderDeveloperModeTests",
            dependencies: ["ProviderDeveloperMode"]
        ),
    ]
)
