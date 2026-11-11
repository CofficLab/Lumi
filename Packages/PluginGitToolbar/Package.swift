// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitToolbar",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(
            name: "PluginGitToolbar",
            targets: ["PluginGitToolbar"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.22.0"),
        .package(path: "../ProviderGit"),
        .package(path: "../ProviderGitRepositoryWatch"),
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
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
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
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Tests/PluginGitToolbarTests"
        ),
    ]
)
