// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMContext",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginLLMContext", targets: ["PluginLLMContext"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderLLMContext"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessage"),
        .package(path: "../../Vendor/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginLLMContext",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLLM",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderConversation",
                "ProviderChatSection",
                "ProviderLifecycleHooks",
                "ProviderLLMContext",
                "ProviderLLMManager",
                "ProviderMessage",
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "LumiUI",
            ],
            path: "Sources/PluginLLMContext",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginLLMContextTests",
            dependencies: [
                "PluginLLMContext",
                "KitLLM",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderMessage",
            ],
            path: "Tests/PluginLLMContextTests"
        ),
    ]
)
