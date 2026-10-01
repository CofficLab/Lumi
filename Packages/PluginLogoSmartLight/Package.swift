// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLogoSmartLight",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginLogoSmartLight",
            targets: ["PluginLogoSmartLight"]
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
            name: "PluginLogoSmartLight",
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
                "Sources/PluginLogoSmartLight/Views/README.md",
                "Sources/PluginLogoSmartLight/Views/MenuBar/README.md",
                "Sources/PluginLogoSmartLight/Support/README.md",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLogoSmartLightTests",
            dependencies: ["PluginLogoSmartLight"]
        )
    ]
)
