// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginTextActions",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginTextActions", targets: ["TextActionsPlugin"])
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLLM"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderSettingView")
    ],
    targets: [
        .target(
            name: "TextActionsPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "TextActionsPluginTests",
            dependencies: ["TextActionsPlugin"],
            path: "Tests"
        )
    ]
)
