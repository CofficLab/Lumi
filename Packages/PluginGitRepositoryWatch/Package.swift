// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitRepositoryWatch",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "PluginGitRepositoryWatch",
            targets: ["PluginGitRepositoryWatch"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderGitRepositoryWatch"),
        .package(path: "../ProviderProject"),
    ],
    targets: [
        .target(
            name: "PluginGitRepositoryWatch",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Sources/PluginGitRepositoryWatch"
        ),
        .testTarget(
            name: "PluginGitRepositoryWatchTests",
            dependencies: [
                "PluginGitRepositoryWatch",
                .product(name: "ProviderGitRepositoryWatch", package: "ProviderGitRepositoryWatch"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Tests/PluginGitRepositoryWatchTests"
        ),
    ]
)
