// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLogoCoffic",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginLogoCoffic",
            targets: ["PluginLogoCoffic"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../ProviderLogo"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginLogoCoffic",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: ".",
            exclude: [
                "Tests",
                "build",
                "README.md",
                "Sources/PluginLogoCoffic/Views/README.md",
                "Sources/PluginLogoCoffic/Views/MenuBar/README.md",
                "Sources/PluginLogoCoffic/Support/README.md",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLogoCofficTests",
            dependencies: ["PluginLogoCoffic"]
        )
    ]
)
