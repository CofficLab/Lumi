// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentPlanStorage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAgentPlanStorage", targets: ["PluginAgentPlanStorage"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginAgentPlanStorage",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Sources/PluginAgentPlanStorage"
        ),
        .testTarget(
            name: "PluginAgentPlanStorageTests",
            dependencies: ["PluginAgentPlanStorage", "KitAgentTool"],
            path: "Tests/PluginAgentPlanStorageTests"
        ),
    ]
)
