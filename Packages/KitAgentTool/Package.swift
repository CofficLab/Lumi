// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitAgentTool",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitAgentTool",
            targets: ["KitAgentTool"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "KitAgentTool",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KitAgentToolTests",
            dependencies: ["KitAgentTool"],
            path: "Tests"
        )
    ]
)
