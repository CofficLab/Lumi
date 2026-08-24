// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSettings",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "SettingsPlugin",
            targets: ["SettingsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "SettingsPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/SettingsPlugin",
            resources: [
                .process("Localizable.xcstrings")
            ]
        )
    ]
)
