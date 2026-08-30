// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCodeEditorHost",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginCodeEditorHost", targets: ["PluginCodeEditorHost"])],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../EditorContracts"),
        .package(path: "../EditorService"),
        .package(path: "../EditorSource"),
        .package(path: "../EditorLanguageRuntime"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginCodeEditorHost",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorSource", package: "EditorSource"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "PluginCodeEditorHostTests",
            dependencies: [
                "PluginCodeEditorHost",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
            ]
        ),
    ]
)
