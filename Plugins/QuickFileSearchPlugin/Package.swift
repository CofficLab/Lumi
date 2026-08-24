// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginQuickFileSearch",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginQuickFileSearch",
            targets: ["QuickFileSearchPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ProviderProject"),
        .package(path: "../../Packages/ProviderRootView"),
        .package(path: "../../Packages/ProviderSettingView"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "QuickFileSearchPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "QuickFileSearchPluginTests",
            dependencies: [
                "QuickFileSearchPlugin",
            ],
            path: "Tests"
        )
    ]
)
