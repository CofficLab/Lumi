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
            name: "OpenRemotePlugin",
            targets: ["OpenRemotePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),        .package(path: "../LumiUI"),
        .package(path: "../ShellKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "OpenRemotePlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "OpenRemotePluginTests",
            dependencies: ["OpenRemotePlugin"],
            path: "Tests"
        )
    ]
)
