// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSampleDecorationEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginSampleDecorationEditor",
            targets: ["PluginSampleDecorationEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginSampleDecorationEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService",
            path: "Sources"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginSampleDecorationEditorTests",
            dependencies: ["PluginSampleDecorationEditor"],
            path: "Tests"
        )
    ]
)
