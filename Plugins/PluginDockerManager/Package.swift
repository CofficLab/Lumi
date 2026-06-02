// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDockerManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginDockerManager",
            targets: ["PluginDockerManager"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/DockerKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginDockerManager",
            dependencies: [
                .product(name: "DockerKit", package: "DockerKit",
            path: "Sources"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginDockerManagerTests",
            dependencies: [
                "PluginDockerManager",
                .product(name: "DockerKit", package: "DockerKit"),
            ],
            path: "Tests"
        )
    ]
)
