// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderToolManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderToolManager",
            targets: ["ProviderToolManager"]
        ),
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
    ],
    targets: [
        .target(
            name: "ProviderToolManager",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
            ],
            path: "Sources/ProviderToolManager"
        ),
        .testTarget(
            name: "ProviderToolManagerTests",
            dependencies: ["ProviderToolManager"],
            path: "Tests/ProviderToolManagerTests"
        )
    ]
)
