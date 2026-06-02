// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorRailReferences",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorRailReferences",
            targets: ["PluginEditorRailReferences"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorRailReferences",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorRailReferences",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorRailReferencesTests",
            dependencies: ["PluginEditorRailReferences"],
            path: "Tests"
        )
    ]
)
