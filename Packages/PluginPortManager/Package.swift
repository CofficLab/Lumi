// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPortManager",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(
            name: "PluginPortManager",
            targets: ["PortManagerPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(path: "../KitShell"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0")
    ],
    targets: [
.target(
            name: "PortManagerPlugin",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "LumiLoggingKit", package: "LumiLogging")
            ],
            path: "Sources/PluginPortManager",
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "PortManagerPluginTests",
            dependencies: [.target(name: "PortManagerPlugin")],
            path: "Tests"
        )
    ]
)
