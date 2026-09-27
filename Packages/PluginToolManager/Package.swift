// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginToolManager", targets: ["PluginToolManager"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KitFileSystem"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderProject"),
        .package(path: "../KitShell"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginToolManager",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitFileSystem", package: "KitFileSystem"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginToolManager",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginToolManagerTests",
            dependencies: [
                "PluginToolManager",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ],
            path: "Tests/PluginToolManagerTests"
        ),
    ]
)
