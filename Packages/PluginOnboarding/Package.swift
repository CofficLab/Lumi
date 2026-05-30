// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOnboarding",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginOnboarding",
            targets: ["PluginOnboarding"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginOnboarding",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginOnboarding",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginOnboardingTests",
            dependencies: ["PluginOnboarding"],
            path: "Tests/PluginOnboardingTests"
        )
    ]
)
