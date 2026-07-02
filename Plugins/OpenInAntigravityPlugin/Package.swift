// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenInAntigravityPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenInAntigravityPlugin",
            targets: ["OpenInAntigravityPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "OpenInAntigravityPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "OpenInAntigravityPluginTests",
            dependencies: ["OpenInAntigravityPlugin"],
            path: "Tests"
        )
    ]
)
