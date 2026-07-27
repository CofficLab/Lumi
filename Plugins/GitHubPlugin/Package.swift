// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitHubPlugin",
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
        .package(path: "../../Packages/GitHubKit"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "GitHubPlugin",
            dependencies: [
                .product(name: "GitHubKit", package: "GitHubKit"),
                .product(name: "LumiKernel", package: "LumiKernel"),
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
