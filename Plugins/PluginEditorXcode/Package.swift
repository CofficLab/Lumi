// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorXcode",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorXcode",
            targets: ["PluginEditorXcode"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCodeEditSourceEditor"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../PluginLSPServiceEditor"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/XcodeKit"),
        .package(path: "../../Packages/XcodeProjectGen"),
        .package(url: "https://github.com/tuist/XcodeProj", .upToNextMajor(from: "9.11.0")),
    ],
    targets: [
        .target(
            name: "PluginEditorXcode",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "PluginLSPServiceEditor", package: "PluginLSPServiceEditor"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "XcodeKit", package: "XcodeKit"),
                .product(name: "XcodeProjectGen", package: "XcodeProjectGen"),
                .product(name: "XcodeProj", package: "XcodeProj"),
            ],
            path: "Sources/PluginEditorXcode",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorXcodeTests",
            dependencies: ["PluginEditorXcode"],
            path: "Tests/PluginEditorXcodeTests"
        )
    ]
)
