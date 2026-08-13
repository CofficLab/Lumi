// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StateMonitorPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StateMonitorPlugin", targets: ["StateMonitorPlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
    ],
    targets: [
        .target(
            name: "StateMonitorPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "StateMonitorPluginTests",
            dependencies: [
                .target(name: "StateMonitorPlugin"),
            ],
            path: "Tests"
        )
    ]
)
