// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorPreview",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginEditorPreview", targets: ["PluginEditorPreview"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitMarkdown"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginEditorPreview",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitMarkdown", package: "KitMarkdown"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginEditorPreviewTests",
            dependencies: [
                "PluginEditorPreview",
                .product(name: "ProviderProject", package: "ProviderProject"),
            ]
        ),
    ]
)
