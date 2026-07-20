// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatComposerPlugin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatComposerPlugin",
            targets: ["ChatComposerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LumiCoreChat"),
    ],
    targets: [
        .target(
            name: "ChatComposerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiCoreChat", package: "LumiCoreChat"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ChatComposerPluginTests",
            dependencies: ["ChatComposerPlugin"],
            path: "Tests"
        )
    ]
)
