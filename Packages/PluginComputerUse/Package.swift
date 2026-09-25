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
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "ComputerUsePlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
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
