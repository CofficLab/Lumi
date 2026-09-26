// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginGit",
            targets: ["GitPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/nookery/LibGit2Swift", .branch("main")),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderEditor"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderGit"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderSkill"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../KitLocalization"),        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../KitShell"),
        .package(path: "../KitSuperLog"),
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
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
                .product(name: "KitLocalization", package: "KitLocalization"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings"),
                // 保留 Skills 目录结构（.copy），否则 Bundle.module 遍历会失败。
                .copy("../Resources/Skills")
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
