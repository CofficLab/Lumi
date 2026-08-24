// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInAntigravity",
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
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "OpenInAntigravityPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
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
