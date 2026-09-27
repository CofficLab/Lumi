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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderActivityHeatmap"),
        .package(path: "../ProviderGit"),
        .package(path: "../ProviderGitRepositoryWatch"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderIdleTime"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderStorage"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "PluginActivityHeatmap",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderActivityHeatmap", package: "ProviderActivityHeatmap"),
                .product(name: "ProviderGit", package: "ProviderGit"),
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginActivityHeatmapTests",
            dependencies: [
                "PluginActivityHeatmap",
                .product(name: "ProviderGit", package: "ProviderGit"),
            ]
        ),
    ]
)
