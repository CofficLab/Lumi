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
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/ProviderToolManager"),
        .package(path: "../../Packages/ProviderSettingView"),
        .package(path: "../../Packages/ProviderMessage"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ComputerUsePlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/ComputerUsePlugin",
            resources: [.process("Resources/Localizable.xcstrings")]
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
