// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDockerManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginDockerManager", targets: ["DockerManagerPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderRootView"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../KitShell"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2")
    ],
    targets: [
.target(
            name: "DockerManagerPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "LumiLoggingKit", package: "LumiLogging")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "DockerManagerPluginTests",
            dependencies: [.target(name: "DockerManagerPlugin")],
            path: "Tests"
        )
    ]
)
