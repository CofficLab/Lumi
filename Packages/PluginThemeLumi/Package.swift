// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeLumi",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ThemeLumiPlugin",
            targets: ["ThemeLumiPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),        .package(path: "../LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeLumiPlugin",
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
            name: "ThemeLumiPluginTests",
            dependencies: ["ThemeLumiPlugin"],
            path: "Tests"
        )
    ]
)
