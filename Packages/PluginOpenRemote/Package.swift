// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenRemote",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginOpenRemote",
            targets: ["PluginOpenRemote"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ShellKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginOpenRemote",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginOpenRemote",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginOpenRemoteTests",
            dependencies: ["PluginOpenRemote"],
            path: "Tests/PluginOpenRemoteTests"
        )
    ]
)
