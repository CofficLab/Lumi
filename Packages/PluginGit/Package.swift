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
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LibGit2Swift"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderEditor"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderGit"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../KitShell"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "GitPlugin",
            dependencies: [
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
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
