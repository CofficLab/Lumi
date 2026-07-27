// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentToolKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentToolKit",
            targets: ["AgentToolKit"]
        )
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiKernel"),
        .package(path: "../LumiCoreMessage"),
    ],
    targets: [
        .target(
            name: "AgentToolKit",
            dependencies: [
                "SuperLogKit",
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AgentToolKitTests",
            dependencies: ["AgentToolKit"],
            path: "Tests"
        )
    ]
)
