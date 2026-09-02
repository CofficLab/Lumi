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
        .package(path: "../KernelCore"),
        .package(path: "../EditorContracts"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderDocsView"),
    ],
    targets: [
        .target(
            name: "QuickFileSearchPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
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
