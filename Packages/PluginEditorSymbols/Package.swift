// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorSymbols",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSymbolsPlugin",
            targets: ["EditorSymbolsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorSymbolsPlugin",
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
            name: "EditorSymbolsPluginTests",
            dependencies: ["EditorSymbolsPlugin"],
            path: "Tests"
        )
    ]
)
