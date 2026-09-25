// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentTempStorage",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentTempStorage", targets: ["PluginAgentTempStorage"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .testTarget(
            name: "PluginAgentTempStorageTests",
            dependencies: ["PluginAgentTempStorage", "KitAgentTool"]
        ),
        .target(
            name: "PluginAgentTempStorage",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLocalization",
                "ProviderStorage",
                "ProviderToolManager",
                "KitSuperLog",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
    ]
)
