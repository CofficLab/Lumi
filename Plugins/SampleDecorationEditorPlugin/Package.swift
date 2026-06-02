// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SampleDecorationEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SampleDecorationEditorPlugin",
            targets: ["SampleDecorationEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "SampleDecorationEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SampleDecorationEditorPluginTests",
            dependencies: ["SampleDecorationEditorPlugin"],
            path: "Tests"
        )
    ]
)
