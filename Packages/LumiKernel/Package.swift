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
        .package(path: "../SuperLogKit"),
        .package(name: "HttpKit", path: "../HttpKit"),
        .package(path: "../KeychainKit"),
    ],
    targets: [
        .target(
            name: "LumiKernel",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "KeychainKit", package: "KeychainKit"),
            ],
            path: "Sources/LumiKernel",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LumiKernelTests",
            dependencies: ["LumiKernel"]
        )
    ]
)
