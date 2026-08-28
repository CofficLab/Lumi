// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOnboarding",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOnboarding", targets: ["PluginOnboarding"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderOnboarding"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginOnboarding",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderOnboarding", package: "ProviderOnboarding"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOnboardingTests",
            dependencies: [
                "PluginOnboarding",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderOnboarding", package: "ProviderOnboarding"),
            ]
        ),
    ]
)
