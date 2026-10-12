// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginComputerUse",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginComputerUse", targets: ["ComputerUsePlugin"]),
        .executable(name: "AXFixture", targets: ["AXFixture"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7"),
    ],
    targets: [
        .target(
            name: "ComputerUsePlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ComputerUsePlugin",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ComputerUsePluginTests",
            dependencies: [
                "ComputerUsePlugin",
            ],
            path: "Tests/ComputerUsePluginTests"
        ),
        .executableTarget(
            name: "AXFixture",
            path: "Sources/AXFixture"
        ),
    ]
)
