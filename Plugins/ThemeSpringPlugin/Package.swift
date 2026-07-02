// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeSpringPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeSpringPlugin",
            targets: ["ThemeSpringPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeSpringPlugin",
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
            name: "ThemeSpringPluginTests",
            dependencies: ["ThemeSpringPlugin"],
            path: "Tests"
        )
    ]
)
