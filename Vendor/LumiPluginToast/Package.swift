// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginToast",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PluginToast", targets: ["PluginToast"]),
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
        .package(path: "../LumiLogging"),
        .package(path: "../LumiLocalization"),
        .package(path: "../LumiProviders"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginToast",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginToastTests",
            dependencies: [
                "PluginToast",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
            ]
        ),
    ]
)
