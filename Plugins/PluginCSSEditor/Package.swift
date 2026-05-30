// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCSSEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginCSSEditor",
            targets: ["PluginCSSEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginCSSEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginCSSEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginCSSEditorTests",
            dependencies: ["PluginCSSEditor"],
            path: "Tests/PluginCSSEditorTests"
        )
    ]
)
