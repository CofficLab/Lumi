// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDevice",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginDevice",
            targets: ["PluginDevice"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.22.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.0"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
    ],
    targets: [
        .target(
            name: "PluginDevice",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitAgentTool",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderToolManager",
                "PluginDeviceThermalBridge",
            ],
            path: ".",
            exclude: [
                "Tests",
                "build",
                "README.md",
                "Sources/PluginDevice/Models/README.md",
                "Sources/PluginDevice/Services/README.md",
                "Sources/PluginDevice/ViewModels/README.md",
                "Sources/PluginDevice/Views/README.md",
                "Sources/PluginDevice/Views/MenuBar/README.md",
                "Sources/PluginDevice/Support/README.md",
                "Sources/PluginDeviceThermalBridge",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        // 温度采集桥接层:纯 ObjC,封装 IOKit 私有 HID API。
        // SwiftPM 单 target 不支持混编,故拆为独立 target。
        .target(
            name: "PluginDeviceThermalBridge",
            path: "Sources/PluginDeviceThermalBridge"
        ),
        .testTarget(
            name: "PluginDeviceTests",
            dependencies: [
                "PluginDevice",
                "KitAgentTool",
                "ProviderMessage",
                "ProviderMessageRendering",
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
            ]
        )
    ]
)
