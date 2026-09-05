// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitWorkspace",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginGitWorkspace",
            targets: ["PluginGitWorkspace"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../PluginGit"),
        .package(path: "../ProviderGitRepositoryWatch"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "PluginGitWorkspace",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "PluginGit", package: "PluginGit"),
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ],
            path: "Sources/PluginGitWorkspace"
        ),
        .testTarget(
            name: "PluginGitWorkspaceTests",
            dependencies: ["PluginGitWorkspace", "KernelCore", "ProviderActivityBar", "ProviderContentView", "ProviderProject", "ProviderRootView", "ProviderToolbar"]
        ),
    ]
)
