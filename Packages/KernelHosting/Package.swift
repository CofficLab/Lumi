// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KernelHosting",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "KernelHosting", targets: ["KernelHosting"]),
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "KernelHosting",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        )
    ]
)
