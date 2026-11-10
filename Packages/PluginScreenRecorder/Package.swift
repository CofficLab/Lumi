// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginScreenRecorder",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginScreenRecorder", targets: ["ScreenRecorderPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "ScreenRecorderPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ScreenRecorderPlugin"
        ),
        .testTarget(
            name: "ScreenRecorderPluginTests",
            dependencies: [
                "ScreenRecorderPlugin",
            ],
            path: "Tests/ScreenRecorderPluginTests"
        ),
    ]
)
