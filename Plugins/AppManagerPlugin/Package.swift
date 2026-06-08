// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppManagerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppManagerPlugin",
            targets: ["AppManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "AppManagerPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources/AppManagerPlugin.swift"]
        ),
        .testTarget(
            name: "AppManagerPluginTests",
            dependencies: ["AppManagerPlugin"],
            path: "Tests"
        )
    ]
)
