// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDevice",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginDevice",
            targets: ["PluginDevice"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../../Vendor/LumiLogging"),
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
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
            ]
        )
    ]
)
