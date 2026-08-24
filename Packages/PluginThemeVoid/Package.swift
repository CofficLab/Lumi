// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeVoid",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeVoidPlugin",
            targets: ["ThemeVoidPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),        .package(path: "../LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeVoidPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeVoidPluginTests",
            dependencies: ["ThemeVoidPlugin"],
            path: "Tests"
        )
    ]
)
