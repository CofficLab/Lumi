// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginFileLog",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginFileLog",
            targets: ["PluginFileLog"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginFileLog",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Sources/PluginFileLog"
        ),
        .testTarget(
            name: "PluginFileLogTests",
            dependencies: ["PluginFileLog"],
            path: "Tests/PluginFileLogTests"
        )
    ]
)
