// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenInKit",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "OpenInKit", targets: ["OpenInKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.4.0"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "OpenInKit",
            dependencies: [
                "KitAgentTool",
                "LumiUI",
                .product(name: "ProviderProject", package: "LumiProviders"),
            ],
            path: "Sources/OpenInKit",
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "OpenInKitTests",
            dependencies: [
                "OpenInKit",
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderProject", package: "LumiProviders"),
            ]
        ),
    ]
)
