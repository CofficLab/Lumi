// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginNetto",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "PluginNetto",
            targets: ["NettoPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderDocsView"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1")
    ],
    targets: [
.target(
            name: "NettoPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "LumiLoggingKit", package: "LumiLogging")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "NettoPluginTests",
            dependencies: [.target(name: "NettoPlugin")],
            path: "Tests"
        )
    ]
)
