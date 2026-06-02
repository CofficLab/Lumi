// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorBottomTerminal",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorBottomTerminal",
            targets: ["PluginEditorBottomTerminal"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/TerminalCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorBottomTerminal",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "TerminalCoreKit", package: "TerminalCoreKit"),
            ],
            path: "Sources/PluginEditorBottomTerminal",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorBottomTerminalTests",
            dependencies: ["PluginEditorBottomTerminal"],
            path: "Tests"
        )
    ]
)
