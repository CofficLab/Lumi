// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoTaskPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AutoTaskPlugin",
            targets: ["AutoTaskPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "AutoTaskPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AutoTaskPluginTests",
            dependencies: ["AutoTaskPlugin"],
            path: "Tests"
        )
    ]
)
