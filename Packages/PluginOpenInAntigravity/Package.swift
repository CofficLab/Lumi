// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInAntigravity",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenInAntigravity", targets: ["PluginOpenInAntigravity"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../KitOpenIn"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.12.0")
    ],
    targets: [
        .target(
            name: "PluginOpenInAntigravity",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitOpenIn",
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                "ProviderToolManager",
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Sources/PluginOpenInAntigravity",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOpenInAntigravityTests",
            dependencies: [
                "PluginOpenInAntigravity",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitOpenIn", package: "KitOpenIn"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ]
        ),
    ]
)
