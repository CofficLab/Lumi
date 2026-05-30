// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeOrchard",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeOrchard",
            targets: ["PluginThemeOrchard"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../LumiCodeEditSourceEditor"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginThemeOrchard",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeOrchard",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeOrchardTests",
            dependencies: ["PluginThemeOrchard"],
            path: "Tests/PluginThemeOrchardTests"
        )
    ]
)
