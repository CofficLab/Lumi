// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCodeEditor",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginCodeEditor", targets: ["PluginCodeEditor"]),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../PluginEditorHost"),
        .package(path: "../PluginProjectFileTree"),
        .package(path: "../EditorContracts"),
        .package(path: "../EditorService"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderPluginControl"),
        .package(path: "../ProviderRailView"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginCodeEditor",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "PluginProjectFileTree", package: "PluginProjectFileTree"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginCodeEditorTests",
            dependencies: [
                "PluginCodeEditor",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "PluginEditorHost", package: "PluginEditorHost"),
                .product(name: "PluginProjectFileTree", package: "PluginProjectFileTree"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
            ]
        ),
    ]
)
