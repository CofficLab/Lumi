// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenInKit",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OpenInKit", targets: ["OpenInKit"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderProject"),
    ],
    targets: [
        .target(
            name: "OpenInKit",
            dependencies: [
                "KitAgentTool",
                "LumiUI",
                "ProviderProject",
            ],
            path: "Sources/OpenInKit",
            resources: [.process("../../Resources")]
        ),
    ]
)
