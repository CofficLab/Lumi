// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSwiftPrimitiveTypesEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginSwiftPrimitiveTypesEditor",
            targets: ["PluginSwiftPrimitiveTypesEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginSwiftPrimitiveTypesEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginSwiftPrimitiveTypesEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginSwiftPrimitiveTypesEditorTests",
            dependencies: ["PluginSwiftPrimitiveTypesEditor"],
            path: "Tests/PluginSwiftPrimitiveTypesEditorTests"
        )
    ]
)
