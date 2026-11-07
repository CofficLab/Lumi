// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginCommand",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginCommand", targets: ["PluginCommand"])
    ],
    dependencies: [
        .package(path: "../LumiLogging"),
        .package(path: "../LumiKernel"),
        .package(path: "../LumiProviders"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiLocalization"),
    ],
    targets: [
        .target(
            name: "PluginCommand",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderCommand", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginCommand",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginCommandTests",
            dependencies: ["PluginCommand"],
            path: "Tests/PluginCommandTests"
        ),
    ]
)
