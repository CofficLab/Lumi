// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitHubIssue",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginGitHubIssue", targets: ["PluginGitHubIssue"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderToolManager"),
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
                .product(name: "KitTestSupport", package: "KitTestSupport"),
            ],
            path: "Tests/PluginGitHubIssueTests"
        ),
    ]
)
