// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFileTree",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginProjectFileTree", targets: ["PluginProjectFileTree"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderToast"),
        .package(path: "../KitFileSystem"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginProjectFileTree",
            dependencies: [
                "KernelCore",
                "ProviderRailView",
                "ProviderProject",
                "ProviderStorage",
                "ProviderConversationInput",
                "ProviderToast",
                "KitFileSystem",
                "KitSuperLog",
                "KitLocalization",
                "LumiUI",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginProjectFileTreeTests",
            dependencies: [
                .target(name: "PluginProjectFileTree"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
            ],
            path: "Tests"
        ),
    ]
)
