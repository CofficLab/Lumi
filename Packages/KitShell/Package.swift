// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KitShell",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KitShell", targets: ["KitShell"]),
    ],
    dependencies: [
        .package(path: "../KitLocalization"),
    ],

    targets: [
        .target(
            name: "KitShell",
            dependencies: [
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(name: "KitShellTests", dependencies: ["KitShell"],
            path: "Tests"),
    ]
)