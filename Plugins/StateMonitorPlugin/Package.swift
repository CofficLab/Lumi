// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StateMonitorPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StateMonitorPlugin", targets: ["StateMonitorPlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
    ],
    targets: [
        .target(
            name: "StateMonitorPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
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
