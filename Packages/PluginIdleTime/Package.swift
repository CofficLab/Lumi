// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginIdleTime",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginIdleTime",
            targets: ["PluginIdleTime"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderMenuBar"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderIdleTime"),
    ],
    targets: [
        .target(
            name: "PluginIdleTime",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderMenuBar", package: "ProviderMenuBar"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
            ],
            path: ".",
            exclude: [
                "Tests",
                "build",
                "README.md",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginIdleTimeTests",
            dependencies: [
                "PluginIdleTime",
                "KernelCore",
                "ProviderIdleTime",
            ],
            path: "Tests/PluginIdleTimeTests"
        )
    ]
)
