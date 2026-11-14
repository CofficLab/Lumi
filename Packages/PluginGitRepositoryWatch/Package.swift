// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitRepositoryWatch",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(
            name: "PluginGitRepositoryWatch",
            targets: ["PluginGitRepositoryWatch"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(path: "../ProviderGitRepositoryWatch"),
    ],
    targets: [
        .target(
            name: "PluginGitRepositoryWatch",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderProject", package: "LumiProviders"),
            ],
            path: "Sources/PluginGitRepositoryWatch"
        ),
        .testTarget(
            name: "PluginGitRepositoryWatchTests",
            dependencies: [
                "PluginGitRepositoryWatch",
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderProject", package: "LumiProviders"),
            ],
            path: "Tests/PluginGitRepositoryWatchTests"
        ),
    ]
)
