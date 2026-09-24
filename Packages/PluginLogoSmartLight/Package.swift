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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderLogo"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginLogoSmartLight",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
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
