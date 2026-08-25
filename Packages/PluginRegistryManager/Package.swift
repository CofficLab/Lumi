// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginRegistryManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "PluginRegistryManager",
            targets: ["RegistryManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog")
    ],
    targets: [
.target(
            name: "RegistryManagerPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "RegistryManagerPluginTests",
            dependencies: [.target(name: "RegistryManagerPlugin")],
            path: "Tests"
        )
    ]
)
