// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitRepositoryWatch",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "PluginGitRepositoryWatch",
            targets: ["PluginGitRepositoryWatch"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderGitRepositoryWatch"),
        .package(path: "../ProviderProject"),
    ],
    targets: [
        .target(
            name: "PluginGitRepositoryWatch",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
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
