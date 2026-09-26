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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderSkill"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitSuperLog")
    ],
    targets: [
        .target(
            name: "BookletMakerPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "KitSuperLog", package: "KitSuperLog")
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
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests"
        )
    ]
)
