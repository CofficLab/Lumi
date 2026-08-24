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
        .package(path: "../KernelCore"),
        .package(path: "../AgentToolKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager")
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
