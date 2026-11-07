// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitWorkspace",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginGitWorkspace",
            targets: ["PluginGitWorkspace"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderGit"),
        .package(path: "../ProviderGitRepositoryWatch"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../PluginRootView")
    ],
    targets: [
        .target(
            name: "PluginGitWorkspace",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderGit", package: "ProviderGit"),
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
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
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                "ProviderChatSection",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "PluginRootView", package: "PluginRootView"),
            ]
        ),
    ]
)
