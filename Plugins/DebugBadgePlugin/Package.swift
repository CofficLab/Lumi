// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DebugBadgePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "DebugBadgePlugin",
            targets: ["DebugBadgePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "DebugBadgePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources"
        )
    ]
)
