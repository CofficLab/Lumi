// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginXcodeBuild",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginXcodeBuild", targets: ["PluginXcodeBuild"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderSkill"),
    ],
    targets: [
        .target(
            name: "PluginXcodeBuild",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "ProviderSkill",
            ],
            path: "Sources/PluginXcodeBuild",
            resources: [
                // 保留 Resources/Skills 目录结构（.copy），否则 Bundle.module 遍历会失败。
                .copy("Resources/Skills")
            ]
        ),
        .testTarget(
            name: "PluginXcodeBuildTests",
            dependencies: [
                "PluginXcodeBuild",
                .product(name: "ProviderSkill", package: "ProviderSkill"),
            ],
            path: "Tests/PluginXcodeBuildTests"
        ),
    ]
)