// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolManager",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginToolManager", targets: ["PluginToolManager"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KitFileSystem"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitShell"),
        .package(path: "../LumiUI"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginToolManager",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitFileSystem", package: "KitFileSystem"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/PluginToolManager"
        ),
        .testTarget(
            name: "PluginToolManagerTests",
            dependencies: [
                "PluginToolManager",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests/PluginToolManagerTests"
        ),
    ]
)
