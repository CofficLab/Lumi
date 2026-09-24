// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginRClick",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginRClick", targets: ["RClickPlugin"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderStorage"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog")
    ],
    targets: [
.target(
            name: "RClickPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "RClickPluginTests",
            dependencies: [
                .target(name: "RClickPlugin"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Tests"
        )
    ]
)
