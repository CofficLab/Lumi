// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SampleInsightsEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SampleInsightsEditorPlugin",
            targets: ["SampleInsightsEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "SampleInsightsEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SampleInsightsEditorPluginTests",
            dependencies: ["SampleInsightsEditorPlugin"],
            path: "Tests"
        )
    ]
)
