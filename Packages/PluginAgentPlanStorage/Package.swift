// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentPlanStorage",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentPlanStorage", targets: ["PluginAgentPlanStorage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginAgentPlanStorage",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
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
