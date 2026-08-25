// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectOverview",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginProjectOverview",
            targets: ["ProjectOverviewPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitLocalization"),        .package(path: "../KitSuperLog"),
        .package(path: "../KitShell"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
    ],
    targets: [
        .target(
            name: "ProjectOverviewPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitLocalization", package: "KitLocalization"),                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderPromptSuggestion", package: "ProviderPromptSuggestion"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ProjectOverviewPluginTests",
            dependencies: ["ProjectOverviewPlugin"],
            path: "Tests"
        )
    ]
)
