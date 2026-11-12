// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginNetto",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(
            name: "PluginNetto",
            targets: ["NettoPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(path: "../KitTestSupport"),
    ],
    targets: [
.target(
            name: "NettoPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Sources/PluginNetto",
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "NettoPluginTests",
            dependencies: [
                .target(name: "NettoPlugin"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "KitTestSupport", package: "KitTestSupport"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Tests"
        )
    ]
)
