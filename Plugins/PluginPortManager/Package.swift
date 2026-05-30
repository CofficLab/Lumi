// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPortManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginPortManager",
            targets: ["PluginPortManager"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginPortManager",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginPortManager",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginPortManagerTests",
            dependencies: ["PluginPortManager"],
            path: "Tests/PluginPortManagerTests"
        )
    ]
)
