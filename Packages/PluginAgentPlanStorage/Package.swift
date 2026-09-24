// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentPlanStorage",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentPlanStorage", targets: ["PluginAgentPlanStorage"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginAgentPlanStorage",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KernelCore", package: "LumiKernel"),
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
