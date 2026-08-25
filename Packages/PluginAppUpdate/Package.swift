// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppUpdate",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppUpdatePlugin",
            targets: ["AppUpdatePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "AppUpdatePlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderNetwork", package: "ProviderNetwork"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AppUpdatePluginTests",
            dependencies: ["AppUpdatePlugin"],
            path: "Tests/AppUpdatePluginTests"
        )
    ]
)
