// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOcr",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOcr", targets: ["PluginOcr"]),
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../KernelCore"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginOcr",
            dependencies: [
                "AgentToolKit",
                "KernelCore",
                "LumiUI",
                "ProviderDocsView",
                "ProviderToolManager",
            ]
        ),
        .testTarget(
            name: "PluginOcrTests",
            dependencies: [
                "PluginOcr",
                "AgentToolKit",
            ]
        ),
    ]
)
