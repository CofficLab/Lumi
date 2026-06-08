// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiskManagerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DiskManagerPlugin",
            targets: ["DiskManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "DiskManagerPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources/DiskManagerPlugin.swift"]
        ),
        .testTarget(
            name: "DiskManagerPluginTests",
            dependencies: ["DiskManagerPlugin"],
            path: "Tests"
        )
    ]
)
