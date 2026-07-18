// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeSummerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeSummerPlugin",
            targets: ["ThemeSummerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeSummerPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeSummerPluginTests",
            dependencies: ["ThemeSummerPlugin"],
            path: "Tests"
        )
    ]
)
