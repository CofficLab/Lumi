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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitShell"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "BrowserPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
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
