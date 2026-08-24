// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOnboarding",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOnboarding", targets: ["PluginOnboarding"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderOnboarding"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
    ],
    targets: [
        .target(
            name: "PluginOnboarding",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderOnboarding", package: "ProviderOnboarding"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
            ]
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
