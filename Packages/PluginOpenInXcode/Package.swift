// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInXcode",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenInXcode", targets: ["PluginOpenInXcode"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../OpenInKit"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2")
    ],
    targets: [
        .target(
            name: "PluginOpenInXcode",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "OpenInKit",
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                "ProviderProject",
                "ProviderToolManager",
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Sources/PluginOpenInXcode",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOpenInXcodeTests",
            dependencies: [
                "PluginOpenInXcode",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "OpenInKit", package: "OpenInKit"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ]
        ),
    ]
)
