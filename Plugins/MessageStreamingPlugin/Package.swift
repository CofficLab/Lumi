// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageStreamingPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageStreamingPlugin", targets: ["MessageStreamingPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "MessageStreamingPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)
