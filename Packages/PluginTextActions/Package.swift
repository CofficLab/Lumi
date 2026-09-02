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
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
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
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
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
