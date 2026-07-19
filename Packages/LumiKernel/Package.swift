// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiKernel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiKernel",
            targets: ["LumiKernel"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "LumiKernel",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/LumiKernel"
        ),
        .testTarget(
            name: "LumiKernelTests",
            dependencies: ["LumiKernel"]
        )
    ]
)