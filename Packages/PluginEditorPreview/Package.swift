// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorPreview",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginEditorPreview", targets: ["PluginEditorPreview"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(path: "../KitMarkdown"),
        .package(path: "../ProviderPanelBottom"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
    ],
    targets: [
        .target(
            name: "PluginEditorPreview",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "KitMarkdown", package: "KitMarkdown"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderPanelBottom", package: "ProviderPanelBottom"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginEditorPreviewTests",
            dependencies: [
                "PluginEditorPreview",
                .product(name: "ProviderProject", package: "LumiProviders"),
            ]
        ),
    ]
)
