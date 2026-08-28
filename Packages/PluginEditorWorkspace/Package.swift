// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorWorkspace",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginEditorWorkspace", targets: ["PluginEditorWorkspace"]),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../PluginEditorHost"),
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
            name: "PluginEditorWorkspace",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginEditorWorkspaceTests",
            dependencies: [
                "PluginEditorWorkspace",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "PluginEditorHost", package: "PluginEditorHost"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
            ]
        ),
    ]
)
