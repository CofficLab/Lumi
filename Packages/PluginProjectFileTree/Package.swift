// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFileTree",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginProjectFileTree", targets: ["PluginProjectFileTree"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../KitFileSystem"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginProjectFileTree",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderConversationInput", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                "KitFileSystem",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginProjectFileTreeTests",
            dependencies: [
                .target(name: "PluginProjectFileTree"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
            ],
            path: "Tests"
        ),
    ]
)
