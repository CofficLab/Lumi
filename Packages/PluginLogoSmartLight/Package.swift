// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLogoSmartLight",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginLogoSmartLight",
            targets: ["PluginLogoSmartLight"]
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
            name: "PluginLogoSmartLight",
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
