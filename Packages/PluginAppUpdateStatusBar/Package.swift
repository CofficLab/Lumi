// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppUpdateStatusBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppUpdateStatusBarPlugin",
            targets: ["AppUpdateStatusBarPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "AppUpdateStatusBarPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AppUpdateStatusBarPluginTests",
            dependencies: ["AppUpdateStatusBarPlugin"],
            path: "Tests"
        )
    ]
)
