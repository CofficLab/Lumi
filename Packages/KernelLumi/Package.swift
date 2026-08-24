// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KernelLumi",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KernelLumi",
            targets: ["KernelLumi"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderWebServer"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
        .package(name: "HttpKit", path: "../HttpKit"),
        .package(path: "../KeychainKit"),
    ],
    targets: [
        .target(
            name: "KernelLumi",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderWebServer", package: "ProviderWebServer"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "KeychainKit", package: "KeychainKit"),
            ],
            path: "Sources/KernelLumi",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "KernelLumiTests",
            dependencies: ["KernelLumi"]
        )
    ]
)
