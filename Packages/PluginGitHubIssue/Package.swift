// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitHubIssue",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginGitHubIssue", targets: ["PluginGitHubIssue"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(path: "../KitTestSupport"),
    ],
    targets: [
        .target(
            name: "PluginGitHubIssue",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Sources/PluginGitHubIssue"
        ),
        .testTarget(
            name: "PluginGitHubIssueTests",
            dependencies: [
                "PluginGitHubIssue",
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitTestSupport", package: "KitTestSupport"),
            ],
            path: "Tests/PluginGitHubIssueTests"
        ),
    ]
)
