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
    ],
    targets: [
        .target(
            name: "PluginOnboarding",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderOnboarding", package: "ProviderOnboarding"),
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
