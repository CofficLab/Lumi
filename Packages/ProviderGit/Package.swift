// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderGit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderGit", targets: ["ProviderGit"]),
    ],
    targets: [
        .target(
            name: "ProviderGit",
            path: "Sources/ProviderGit"
        ),
        .testTarget(
            name: "ProviderGitTests",
            dependencies: ["ProviderGit"],
            path: "Tests/ProviderGitTests"
        ),
    ]
)
