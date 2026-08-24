// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectOverview",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginProjectOverview",
            targets: ["ProjectOverviewPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/ProviderProject"),
        .package(path: "../../Packages/ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "ProjectOverviewPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ProjectOverviewPluginTests",
            dependencies: ["ProjectOverviewPlugin"],
            path: "Tests"
        )
    ]
)
