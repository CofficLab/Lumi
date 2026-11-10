// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolLLMProvider",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginToolLLMProvider", targets: ["PluginToolLLMProvider"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginToolLLMProvider",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                "KitAgentTool",
                "KitLLM",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderMessageRendering",
                "ProviderToolManager",
            ],
            path: "Sources/PluginToolLLMProvider",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginToolLLMProviderTests",
            dependencies: [
                "PluginToolLLMProvider",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitAgentTool",
                "KitLLM",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderMessageRendering",
                "ProviderToolManager",
            ],
            path: "Tests/PluginToolLLMProviderTests"
        ),
    ]
)
