// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginComputerUse",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginComputerUse", targets: ["ComputerUsePlugin"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderMessage"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "ComputerUsePlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
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
    ]
)
