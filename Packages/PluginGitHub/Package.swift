// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitHub",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GitHubPlugin",
            targets: ["GitHubPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../GitHubKit"),
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),        .package(path: "../LumiUI"),
        .package(path: "../ShellKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "GitHubPlugin",
            dependencies: [
                .product(name: "GitHubKit", package: "GitHubKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "GitHubPluginTests",
            dependencies: ["GitHubPlugin"],
            path: "Tests"
        )
    ]
)
