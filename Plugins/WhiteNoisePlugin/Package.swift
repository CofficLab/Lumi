// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhiteNoisePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WhiteNoisePlugin",
            targets: ["WhiteNoisePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "WhiteNoisePlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources"
        )
    ]
)
