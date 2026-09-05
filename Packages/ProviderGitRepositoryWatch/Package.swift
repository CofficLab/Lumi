// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderGitRepositoryWatch",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ProviderGitRepositoryWatch",
            targets: ["ProviderGitRepositoryWatch"]
        ),
    ],
    targets: [
        .target(
            name: "ProviderGitRepositoryWatch",
            path: "Sources/ProviderGitRepositoryWatch"
        ),
        .testTarget(
            name: "ProviderGitRepositoryWatchTests",
            dependencies: ["ProviderGitRepositoryWatch"],
            path: "Tests/ProviderGitRepositoryWatchTests"
        ),
    ]
)
