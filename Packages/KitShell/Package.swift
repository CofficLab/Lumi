// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KitShell",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "KitShell", targets: ["KitShell"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLocalization"),
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