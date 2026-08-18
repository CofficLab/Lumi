// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLogoSmartLight",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLogoSmartLight",
            targets: ["PluginLogoSmartLight"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../ProviderLogo"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLogoSmartLight",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
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
