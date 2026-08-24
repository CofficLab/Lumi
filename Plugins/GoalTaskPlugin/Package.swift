// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGoalTask",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PluginGoalTask", targets: ["GoalTaskPlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ProviderAgentLoop"),
        .package(path: "../../Packages/ProviderChatSection"),
        .package(path: "../../Packages/ProviderConversation"),
        .package(path: "../../Packages/ProviderLifecycleHooks"),
        .package(path: "../../Packages/ProviderStorage"),
        .package(path: "../../Packages/ProviderToolManager")
    ],
    targets: [
        .target(
            name: "GoalTaskPlugin",
            dependencies: [
                "KernelCore",
                "AgentToolKit",
                "SuperLogKit",
                "LumiUI",
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "GoalTaskPluginTests",
            dependencies: ["GoalTaskPlugin"],
            path: "Tests"
        )
    ]
)
