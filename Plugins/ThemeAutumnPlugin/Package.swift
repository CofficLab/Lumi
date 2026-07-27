// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeAutumnPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeAutumnPlugin",
            targets: ["ThemeAutumnPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeAutumnPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeAutumnPluginTests",
            dependencies: ["ThemeAutumnPlugin"],
            path: "Tests"
        )
    ]
)
