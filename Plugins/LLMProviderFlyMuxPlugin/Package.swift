// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderFlyMuxPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderFlyMuxPlugin",
            targets: ["LLMProviderFlyMuxPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderFlyMuxPlugin",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderFlyMuxPluginTests",
            dependencies: ["LLMProviderFlyMuxPlugin"],
            path: "Tests"
        )
    ]
)
