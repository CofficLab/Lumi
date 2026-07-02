// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorStickySymbolBarPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorStickySymbolBarPlugin",
            targets: ["EditorStickySymbolBarPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorStickySymbolBarPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorStickySymbolBarPluginTests",
            dependencies: ["EditorStickySymbolBarPlugin"],
            path: "Tests"
        )
    ]
)
