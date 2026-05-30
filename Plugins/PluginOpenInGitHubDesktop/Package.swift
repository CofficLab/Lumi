// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInGitHubDesktop",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginOpenInGitHubDesktop",
            targets: ["PluginOpenInGitHubDesktop"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginOpenInGitHubDesktop",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginOpenInGitHubDesktop",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginOpenInGitHubDesktopTests",
            dependencies: ["PluginOpenInGitHubDesktop"],
            path: "Tests/PluginOpenInGitHubDesktopTests"
        )
    ]
)
