// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAppUpdate",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderAppUpdate",
            targets: ["ProviderAppUpdate"]
        )
    ],
    targets: [
        .target(
            name: "ProviderAppUpdate",
            path: "Sources/ProviderAppUpdate"
        ),
        .testTarget(
            name: "ProviderAppUpdateTests",
            dependencies: ["ProviderAppUpdate"],
            path: "Tests/ProviderAppUpdateTests"
        )
    ]
)
