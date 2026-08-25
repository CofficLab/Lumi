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
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderLogo"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginLogoCoffic",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
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
