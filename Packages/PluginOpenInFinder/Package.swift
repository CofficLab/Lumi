// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInFinder",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenInFinder", targets: ["PluginOpenInFinder"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../KitOpenIn"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Vendor/LumiProviders")
    ],
    targets: [
        .target(
            name: "PluginOpenInFinder",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitOpenIn",
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                "ProviderToolManager",
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Sources/PluginOpenInFinder",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOpenInFinderTests",
            dependencies: [
                "PluginOpenInFinder",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitOpenIn", package: "KitOpenIn"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ]
        ),
    ]
)
