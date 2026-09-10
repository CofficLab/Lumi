// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderUninstall",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderUninstall",
            targets: ["ProviderUninstall"]
        ),
    ],
    targets: [
        .target(
            name: "ProviderUninstall",
            path: "Sources/ProviderUninstall"
        ),
        .testTarget(
            name: "ProviderUninstallTests",
            dependencies: ["ProviderUninstall"],
            path: "Tests/ProviderUninstallTests"
        )
    ]
)
