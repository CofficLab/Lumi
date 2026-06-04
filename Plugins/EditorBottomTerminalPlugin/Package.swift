// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorBottomTerminalPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorBottomTerminalPlugin",
            targets: ["EditorBottomTerminalPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/TerminalCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorBottomTerminalPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "TerminalCoreKit", package: "TerminalCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorBottomTerminalPluginTests",
            dependencies: ["EditorBottomTerminalPlugin"],
            path: "Tests"
        )
    ]
)
