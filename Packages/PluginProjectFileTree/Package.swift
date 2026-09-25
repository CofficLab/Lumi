// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFileTree",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginProjectFileTree", targets: ["PluginProjectFileTree"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderRailView",
                "ProviderRootView",
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
            ],
            path: "Tests"
        ),
    ]
)
