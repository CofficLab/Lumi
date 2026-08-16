// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWhiteNoise",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginWhiteNoise",
            targets: ["PluginWhiteNoise"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginWhiteNoise",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginWhiteNoise",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "PluginWhiteNoiseTests",
            dependencies: ["PluginWhiteNoise"]
        )
    ]
)
