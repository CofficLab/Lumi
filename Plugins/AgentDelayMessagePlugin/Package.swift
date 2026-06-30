// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentDelayMessagePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentDelayMessagePlugin",
            targets: ["AgentDelayMessagePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "AgentDelayMessagePlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AgentDelayMessagePluginTests",
            dependencies: ["AgentDelayMessagePlugin"],
            path: "Tests"
        )
    ]
)
