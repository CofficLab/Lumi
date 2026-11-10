// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentTempStorage",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentTempStorage", targets: ["PluginAgentTempStorage"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../KitTestSupport"),
    ],
    targets: [
        .testTarget(
            name: "PluginAgentTempStorageTests",
            dependencies: [
                "PluginAgentTempStorage",
                "KitAgentTool",
                .product(name: "KitTestSupport", package: "KitTestSupport"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ]
        ),
        .target(
            name: "PluginAgentTempStorage",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderToolManager",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
    ]
)
