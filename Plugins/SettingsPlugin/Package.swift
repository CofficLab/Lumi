// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SettingsPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "SettingsPlugin",
            targets: ["SettingsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../AppUpdatePlugin"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "SettingsPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "AppUpdatePlugin", package: "AppUpdatePlugin"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/SettingsPlugin",
            resources: [
                .process("Localizable.xcstrings")
            ]
        )
    ]
)
