// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeGithub",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeGithub",
            targets: ["PluginThemeGithub"]
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
            name: "PluginThemeGithub",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeGithub",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeGithubTests",
            dependencies: ["PluginThemeGithub"],
            path: "Tests/PluginThemeGithubTests"
        )
    ]
)
