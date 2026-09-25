// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInGitHubDesktop",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenInGitHubDesktop", targets: ["PluginOpenInGitHubDesktop"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
        .package(path: "../OpenInKit"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "PluginOpenInGitHubDesktop",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLocalization",
                "KitSuperLog",
                "OpenInKit",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderToolManager",
                "ProviderToolbar",
            ],
            path: "Sources/PluginOpenInGitHubDesktop",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOpenInGitHubDesktopTests",
            dependencies: [
                "PluginOpenInGitHubDesktop",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "OpenInKit", package: "OpenInKit"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ]
        ),
    ]
)
