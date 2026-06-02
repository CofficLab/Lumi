// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLSPToolbarEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLSPToolbarEditor",
            targets: ["PluginLSPToolbarEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../PluginLSPServiceEditor"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginLSPToolbarEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "PluginLSPServiceEditor", package: "PluginLSPServiceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginLSPToolbarEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPToolbarEditorTests",
            dependencies: ["PluginLSPToolbarEditor"],
            path: "Tests"
        )
    ]
)
