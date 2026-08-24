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
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/ProviderActivityBar"),
        .package(path: "../../Packages/ProviderContentView"),
        .package(path: "../../Packages/ProviderConversationInput"),
        .package(path: "../../Packages/ProviderDocsView"),
        .package(path: "../../Packages/ProviderRailView"),
        .package(path: "../../Packages/ProviderStorage"),
        .package(path: "../../Packages/ProviderToolManager"),
        .package(path: "../../Packages/ProviderWorkspace"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
        .target(
            name: "StoryWriterPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
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
