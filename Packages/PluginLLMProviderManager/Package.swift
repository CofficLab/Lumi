// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "LLMProviderManagerPlugin", targets: ["LLMProviderManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../LocalizationKit"),
        .package(path: "../KernelLumi"),
        .package(path: "../LLMKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderManagerPlugin",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderManagerPluginTests",
            dependencies: ["LLMProviderManagerPlugin"],
            path: "Tests"
        ),
    ]
)
