// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMemory",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginMemory",
            targets: ["PluginMemory"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../MemoryKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginMemory",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "MemoryKit", package: "MemoryKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginMemory",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginMemoryTests",
            dependencies: ["PluginMemory"],
            path: "Tests/PluginMemoryTests"
        )
    ]
)
