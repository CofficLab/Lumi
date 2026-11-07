// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginBookletMaker",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        // 纯领域逻辑：纸张与折页布局、拆分计划。不依赖 Kernel / Providers / SwiftUI。
        .library(
            name: "BookletMakerCore",
            targets: ["BookletMakerCore"]
        ),
        // 插件层：SuperPlugin 实现 + SwiftUI 界面，供 Lumi 与 GameFactory 共享。
        .library(
            name: "PluginBookletMaker",
            targets: ["PluginBookletMaker"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
        .package(path: "../LumiProviders"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiLocalization"),
        .package(path: "../LumiLogging"),
    ],
    targets: [
        .target(
            name: "BookletMakerCore"
        ),
        .target(
            name: "PluginBookletMaker",
            dependencies: [
                "BookletMakerCore",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Sources/PluginBookletMaker",
            resources: [
                // Resources/ 在仓库根，与 Sources/ 平级；相对 target 目录需上溯两级。
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BookletMakerCoreTests",
            dependencies: ["BookletMakerCore"]
        ),
        .testTarget(
            name: "PluginBookletMakerTests",
            dependencies: [
                "PluginBookletMaker",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Tests/PluginBookletMakerTests"
        ),
    ]
)
