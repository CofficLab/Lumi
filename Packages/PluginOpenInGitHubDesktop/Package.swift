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
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
        .package(path: "../OpenInKit"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginOpenInGitHubDesktop",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "KitSuperLog",
                "OpenInKit",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInGitHubDesktop",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOpenInGitHubDesktopTests",
            dependencies: [
                "PluginOpenInGitHubDesktop",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "OpenInKit", package: "OpenInKit"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ]
        ),
    ]
)
