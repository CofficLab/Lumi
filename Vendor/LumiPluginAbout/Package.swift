// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginAbout",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginAbout",
            targets: ["PluginAbout"]
        )
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
        .package(path: "../LumiLogging"),
        .package(path: "../LumiSettings"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiLocalization"),
    ],
    targets: [
        .target(
            name: "PluginAbout",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginAbout",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAboutTests",
            dependencies: [
                "PluginAbout",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ],
            path: "Tests/PluginAboutTests"
        ),
    ]
)
