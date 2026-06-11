// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRailReferencesPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorRailReferencesPlugin",
            targets: ["EditorRailReferencesPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../EditorBottomReferencesPlugin"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorRailReferencesPlugin",
            dependencies: [
                .product(name: "EditorBottomReferencesPlugin", package: "EditorBottomReferencesPlugin"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorRailReferencesPluginTests",
            dependencies: ["EditorRailReferencesPlugin"],
            path: "Tests"
        )
    ]
)
