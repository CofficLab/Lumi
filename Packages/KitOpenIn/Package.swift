// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitOpenIn",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KitOpenIn", targets: ["KitOpenIn"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.12.0"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.11.1"),
    ],
    targets: [
        .target(
            name: "KitOpenIn",
            dependencies: [
                "KitAgentTool",
                "LumiUI",
                .product(name: "ProviderProject", package: "LumiProviders"),
            ],
            path: "Sources/KitOpenIn",
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "KitOpenInTests",
            dependencies: [
                "KitOpenIn",
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderProject", package: "LumiProviders"),
            ]
        ),
    ]
)
