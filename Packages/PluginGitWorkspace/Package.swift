// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitWorkspace",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginGitWorkspace",
            targets: ["PluginGitWorkspace"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderGit"),
        .package(path: "../ProviderGitRepositoryWatch"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRootView"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2")
    ],
    targets: [
        .target(
            name: "PluginGitWorkspace",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderGit", package: "ProviderGit"),
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Sources/PluginGitWorkspace",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginGitWorkspaceTests",
            dependencies: [
                "PluginGitWorkspace",
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderActivityBar",
                "ProviderChatSection",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                "ProviderProject",
                .product(name: "ProviderRailView", package: "LumiProviders"),
                "ProviderRootView",
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ]
        ),
    ]
)
