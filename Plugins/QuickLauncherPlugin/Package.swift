// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickLauncherPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "QuickLauncherPlugin",
            targets: ["QuickLauncherPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/ProviderCommand"),
        .package(path: "../../Packages/ProviderMessageSender"),
        .package(path: "../../Packages/ProviderSettingView"),
    ],
    targets: [
        .target(
            name: "QuickLauncherPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProviderCommand", package: "ProviderCommand"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "QuickLauncherPluginTests",
            dependencies: ["QuickLauncherPlugin"],
            path: "Tests"
        )
    ]
)
