// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginStoryWriter",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginStoryWriter", targets: ["StoryWriterPlugin"])
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitAgentTool"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderWorkspace"),
        .package(path: "../KitSuperLog")
    ],
    targets: [
        .target(
            name: "StoryWriterPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
                .product(name: "KitSuperLog", package: "KitSuperLog")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "StoryWriterPluginTests",
            dependencies: [.target(name: "StoryWriterPlugin")],
            path: "Tests"
        )
    ]
)
