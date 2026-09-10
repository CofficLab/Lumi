// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginActivityHeatmap",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginActivityHeatmap", targets: ["PluginActivityHeatmap"]),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../PluginGit"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderActivityHeatmap"),
        .package(path: "../ProviderGitRepositoryWatch"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderIdleTime"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginActivityHeatmap",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "PluginGit", package: "PluginGit"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderActivityHeatmap", package: "ProviderActivityHeatmap"),
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginActivityHeatmapTests",
            dependencies: ["PluginActivityHeatmap"]
        ),
    ]
)
