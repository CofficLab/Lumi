// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitRepositoryWatch",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(
            name: "PluginGitRepositoryWatch",
            targets: ["PluginGitRepositoryWatch"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
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
