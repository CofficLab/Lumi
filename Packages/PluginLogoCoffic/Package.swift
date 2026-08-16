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
