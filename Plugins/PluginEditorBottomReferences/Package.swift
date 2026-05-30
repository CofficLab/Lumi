// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorBottomReferences",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorBottomReferences",
            targets: ["PluginEditorBottomReferences"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorBottomReferences",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorBottomReferences",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorBottomReferencesTests",
            dependencies: ["PluginEditorBottomReferences"],
            path: "Tests/PluginEditorBottomReferencesTests"
        )
    ]
)
