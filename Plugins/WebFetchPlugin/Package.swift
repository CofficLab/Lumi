// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WebFetchPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WebFetchPlugin",
            targets: ["WebFetchPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/WebFetchKit"),
    ],
    targets: [
        .target(
            name: "WebFetchPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "WebFetchKit", package: "WebFetchKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WebFetchPluginTests",
            dependencies: ["WebFetchPlugin"],
            path: "Tests"
        )
    ]
)
