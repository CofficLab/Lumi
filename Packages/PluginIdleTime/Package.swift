// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginIdleTime",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginIdleTime",
            targets: ["PluginIdleTime"]
        ),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderMenuBar"),
        .package(path: "../ProviderIdleTime"),
    ],
    targets: [
        .target(
            name: "PluginIdleTime",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderMenuBar", package: "ProviderMenuBar"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
            ],
            path: ".",
            exclude: [
                "Tests",
                "build",
                "README.md",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginIdleTimeTests",
            dependencies: [
                "PluginIdleTime",
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderIdleTime",
            ],
            path: "Tests/PluginIdleTimeTests"
        )
    ]
)
