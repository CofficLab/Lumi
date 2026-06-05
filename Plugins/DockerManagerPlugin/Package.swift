// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockerManagerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DockerManagerPlugin",
            targets: ["DockerManagerPlugin"]
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
            name: "DockerManagerPlugin",
            dependencies: [
                .product(name: "DockerKit", package: "DockerKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DockerManagerPluginTests",
            dependencies: [
                "DockerManagerPlugin",
                .product(name: "DockerKit", package: "DockerKit"),
            ],
            path: "Tests"
        )
    ]
)
