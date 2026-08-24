// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginScreenRecorder",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginScreenRecorder", targets: ["ScreenRecorderPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ProviderDocsView"),
        .package(path: "../../Packages/ProviderSettingView"),
        .package(path: "../../Packages/ProviderStorage"),
        .package(path: "../../Packages/ProviderToolManager"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ScreenRecorderPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/ScreenRecorderPlugin"
        ),
        .testTarget(
            name: "ScreenRecorderPluginTests",
            dependencies: [
                "ScreenRecorderPlugin",
            ],
            path: "Tests/ScreenRecorderPluginTests"
        ),
    ]
)
