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
            path: "Sources/PluginXcodeBuild"
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