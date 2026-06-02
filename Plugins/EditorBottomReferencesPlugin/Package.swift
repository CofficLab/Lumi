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
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorBottomReferencesPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorBottomReferencesPluginTests",
            dependencies: ["EditorBottomReferencesPlugin"],
            path: "Tests"
        )
    ]
)
