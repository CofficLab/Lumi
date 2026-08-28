// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorHost",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginEditorHost", targets: ["PluginEditorHost"])],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../EditorContracts"),
        .package(path: "../EditorService"),
        .package(path: "../EditorSource"),
        .package(path: "../EditorLanguageRuntime"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginEditorHost",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorSource", package: "EditorSource"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "LumiUI", package: "LumiUI"),
            ]
        ),
        .testTarget(
            name: "PluginEditorHostTests",
            dependencies: [
                "PluginEditorHost",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
            ]
        ),
    ]
)
