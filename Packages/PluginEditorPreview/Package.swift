// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorPreview",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginEditorPreview", targets: ["PluginEditorPreview"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../KitMarkdown"),
        .package(path: "../ProviderPanelBottom"),
        .package(path: "../../Vendor/LumiUI"),
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
