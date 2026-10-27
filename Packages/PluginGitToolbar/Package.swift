// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitToolbar",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "PluginGitToolbar",
            targets: ["PluginGitToolbar"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.11.1"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.12.0"),
        .package(path: "../ProviderGit"),
    ],
    targets: [
        .target(
            name: "PluginGitToolbar",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderGit", package: "ProviderGit"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Sources/PluginGitToolbar",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginGitToolbarTests",
            dependencies: [
                "PluginGitToolbar",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderGit", package: "ProviderGit"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Tests/PluginGitToolbarTests"
        ),
    ]
)
