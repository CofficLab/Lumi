// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatInputPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatInputPlugin",
            targets: ["ChatInputPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/ChatInputEditorKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ChatInputPlugin",
            dependencies: [
                .product(name: "ChatInputEditorKit", package: "ChatInputEditorKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ChatInputPluginTests",
            dependencies: [
                "ChatInputPlugin",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
