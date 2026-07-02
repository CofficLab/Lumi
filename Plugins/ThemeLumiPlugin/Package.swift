// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeLumiPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeLumiPlugin",
            targets: ["ThemeLumiPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeLumiPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI")
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
