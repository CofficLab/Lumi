// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLogoManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginLogoManager",
            targets: ["PluginLogoManager"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderLogo"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginLogoManager",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ]
        ),
        .testTarget(
            name: "PluginLogoManagerTests",
            dependencies: ["PluginLogoManager"]
        ),
    ]
)
