// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KitShell",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "KitShell", targets: ["KitShell"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
    ],

    targets: [
        .target(
            name: "KitShell",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/KitShell",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(name: "KitShellTests", dependencies: ["KitShell"],
            path: "Tests"),
    ]
)