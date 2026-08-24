// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLegacyData",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LegacyDataPlugin", targets: ["LegacyDataPlugin"]),
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LegacyDataPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: ".",
            exclude: ["Tests"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "LegacyDataPluginTests",
            dependencies: ["LegacyDataPlugin", "KernelLumi"],
            path: "Tests/LegacyDataPluginTests"
        ),
    ]
)
