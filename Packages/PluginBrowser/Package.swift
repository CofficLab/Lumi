// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBrowser",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginBrowser",
            targets: ["BrowserPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderToolbar"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
    ],
    targets: [
        .target(
            name: "BrowserPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "KitMCP", package: "KitMCP", condition: .when(platforms: [.macOS])),
                .product(name: "ProviderMCP", package: "ProviderMCP", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BrowserPluginTests",
            dependencies: ["BrowserPlugin"],
            path: "Tests"
        )
    ]
)
