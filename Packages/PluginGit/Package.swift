// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGit",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginGit",
            targets: ["GitPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/nookery/LibGit2Swift.git", exact: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(path: "../ProviderEditor"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(path: "../ProviderGit"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(path: "../KitShell"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "GitPlugin",
            dependencies: [
                .product(name: "LibGit2Swift", package: "libgit2swift"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderGit", package: "ProviderGit"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderSkill", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginGit",
            resources: [
                .process("../../Resources/Localizable.xcstrings"),
                // 保留 Skills 目录结构（.copy），否则 Bundle.module 遍历会失败。
                .copy("../../Resources/Skills")
            ]
        ),
        .testTarget(
            name: "GitPluginTests",
            dependencies: [
                "GitPlugin",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderEditor", package: "ProviderEditor"),
            ],
            path: "Tests"
        )
    ]
)
