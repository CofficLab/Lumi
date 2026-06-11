// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorBottomReferencesPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorBottomReferencesPlugin",
            targets: ["EditorBottomReferencesPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorBottomReferencesPlugin",
            dependencies: [
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
            name: "EditorBottomReferencesPluginTests",
            dependencies: ["EditorBottomReferencesPlugin"],
            path: "Tests"
        )
    ]
)
