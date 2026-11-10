// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLogoCoffic",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginLogoCoffic",
            targets: ["PluginLogoCoffic"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiProviders"),
    ],
    targets: [
        .target(
            name: "PluginLogoCoffic",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderLogo", package: "LumiProviders"),
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
