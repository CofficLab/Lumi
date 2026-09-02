// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginGit",
            targets: ["GitPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/nookery/LibGit2Swift", .branch("main")),
        .package(path: "../KernelCore"),
        .package(path: "../EditorContracts"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitLocalization"),        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitShell"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "GitPlugin",
            dependencies: [
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "KitLocalization", package: "KitLocalization"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "GitPluginTests",
            dependencies: [
                "GitPlugin",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
            ],
            path: "Tests"
        )
    ]
)
