// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppLoadedPluginsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppLoadedPluginsPlugin",
            targets: ["AppLoadedPluginsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "AppLoadedPluginsPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AppLoadedPluginsPluginTests",
            dependencies: ["AppLoadedPluginsPlugin"],
            path: "Tests"
        )
    ]
)
