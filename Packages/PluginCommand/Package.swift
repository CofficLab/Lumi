// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCommand",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginCommand", targets: ["PluginCommand"])],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderCommand"),
        .package(path: "../ProviderStorage"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginCommand",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderCommand", package: "ProviderCommand"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources/PluginCommand",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "PluginCommandTests", dependencies: ["PluginCommand"]),
    ]
)
