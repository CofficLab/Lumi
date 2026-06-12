// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSwiftPrimitiveTypesPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSwiftPrimitiveTypesPlugin",
            targets: ["EditorSwiftPrimitiveTypesPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorSwiftPrimitiveTypesPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorSwiftPrimitiveTypesPluginTests",
            dependencies: ["EditorSwiftPrimitiveTypesPlugin"],
            path: "Tests"
        )
    ]
)
