// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBookletMaker",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "PluginBookletMaker",
            targets: ["BookletMakerPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiBookletMaker.git", branch: "main"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderSkill"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1")
    ],
    targets: [
        .target(
            name: "BookletMakerPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "BookletMakerCore", package: "LumiBookletMaker"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "LumiLoggingKit", package: "LumiLogging")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings"),
                // 保留 Skills 目录结构（.copy），否则 Bundle.module 遍历会失败。
                .copy("../Resources/Skills")
            ]
        ),
        .testTarget(
            name: "BookletMakerPluginTests",
            dependencies: [
                .target(name: "BookletMakerPlugin"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests"
        )
    ]
)
