// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLogoCoffic",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLogoCoffic",
            targets: ["PluginLogoCoffic"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../ProviderLogo"),
    ],
    targets: [
        .target(
            name: "PluginLogoCoffic",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
            ],
            path: "Sources/PluginLogoCoffic",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "PluginLogoCofficTests",
            dependencies: ["PluginLogoCoffic"]
        )
    ]
)
