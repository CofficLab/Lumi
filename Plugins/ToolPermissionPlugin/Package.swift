// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolPermissionPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ToolPermissionPlugin",
            targets: ["ToolPermissionPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ToolPermissionPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ToolPermissionPluginTests",
            dependencies: ["ToolPermissionPlugin"],
            path: "Tests"
        )
    ]
)
