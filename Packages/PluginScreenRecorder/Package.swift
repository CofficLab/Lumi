// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginScreenRecorder",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginScreenRecorder", targets: ["ScreenRecorderPlugin"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "ScreenRecorderPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
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
