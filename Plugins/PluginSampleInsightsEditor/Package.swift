// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSampleInsightsEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginSampleInsightsEditor",
            targets: ["PluginSampleInsightsEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginSampleInsightsEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginSampleInsightsEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginSampleInsightsEditorTests",
            dependencies: ["PluginSampleInsightsEditor"],
            path: "Tests"
        )
    ]
)
