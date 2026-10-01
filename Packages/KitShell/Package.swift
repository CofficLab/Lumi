// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KitShell",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KitShell", targets: ["KitShell"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],

    targets: [
        .target(
            name: "KitShell",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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