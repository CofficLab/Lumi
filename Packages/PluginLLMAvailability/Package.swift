// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMAvailability",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLLMAvailability",
            targets: ["PluginLLMAvailability"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LLMKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMAvailability",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMAvailability",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLLMAvailabilityTests",
            dependencies: ["PluginLLMAvailability"],
            path: "Tests/PluginLLMAvailabilityTests"
        )
    ]
)
