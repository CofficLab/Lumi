// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitAgentTool",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "KitAgentTool",
            targets: ["KitAgentTool"]
        )
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "KitAgentTool",
            dependencies: [
                "KitSuperLog",
                .product(name: "KitLocalization", package: "KitLocalization"),
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
