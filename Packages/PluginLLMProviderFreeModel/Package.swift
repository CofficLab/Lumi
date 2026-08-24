// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderFreeModel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderFreeModelPlugin",
            targets: ["LLMProviderFreeModelPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../LLMKit"),
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderFreeModelPlugin",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderFreeModelPluginTests",
            dependencies: ["LLMProviderFreeModelPlugin"],
            path: "Tests"
        )
    ]
)
