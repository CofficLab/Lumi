// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftPrimitiveTypesEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftPrimitiveTypesEditorPlugin",
            targets: ["SwiftPrimitiveTypesEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "SwiftPrimitiveTypesEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftPrimitiveTypesEditorPluginTests",
            dependencies: ["SwiftPrimitiveTypesEditorPlugin"],
            path: "Tests"
        )
    ]
)
