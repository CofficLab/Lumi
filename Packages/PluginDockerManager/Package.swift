// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDockerManager",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginDockerManager", targets: ["DockerManagerPlugin"])
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../KitShell"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiProviders")
    ],
    targets: [
.target(
            name: "DockerManagerPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "LumiLoggingKit", package: "LumiLogging")
            ],
            path: "Sources/PluginDockerManager",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "DockerManagerPluginTests",
            dependencies: [
                .target(name: "DockerManagerPlugin"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Tests"
        )
    ]
)
