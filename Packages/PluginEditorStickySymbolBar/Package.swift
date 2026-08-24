// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorStickySymbolBar",
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
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorStickySymbolBarPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorStickySymbolBarPluginTests",
            dependencies: ["EditorStickySymbolBarPlugin"],
            path: "Tests"
        )
    ]
)
