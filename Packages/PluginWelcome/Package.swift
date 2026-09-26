// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWelcome",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginWelcome", targets: ["PluginWelcome"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderOnboarding"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "PluginWelcome",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderOnboarding", package: "ProviderOnboarding"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginWelcomeTests",
            dependencies: [
                "PluginWelcome",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderOnboarding", package: "ProviderOnboarding"),
            ]
        ),
    ]
)
