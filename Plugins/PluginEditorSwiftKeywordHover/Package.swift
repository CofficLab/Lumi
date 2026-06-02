// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorSwiftKeywordHover",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorSwiftKeywordHover",
            targets: ["PluginEditorSwiftKeywordHover"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorSwiftKeywordHover",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginEditorSwiftKeywordHover",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorSwiftKeywordHoverTests",
            dependencies: ["PluginEditorSwiftKeywordHover"],
            path: "Tests"
        )
    ]
)
