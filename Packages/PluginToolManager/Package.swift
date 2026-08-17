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
        .package(path: "../AgentToolKit"),
        .package(path: "../FileSystemKit"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ShellKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginToolManager",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "FileSystemKit", package: "FileSystemKit"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginToolManager"
        ),
    ]
)
