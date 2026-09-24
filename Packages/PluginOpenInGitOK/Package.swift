// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInGitOK",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenInGitOK", targets: ["PluginOpenInGitOK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
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
            name: "PluginOpenInGitOK",
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
            path: "Sources/PluginOpenInGitOK",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOpenInGitOKTests",
            dependencies: [
                "PluginOpenInGitOK",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "OpenInKit", package: "OpenInKit"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ]
        ),
    ]
)
