// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageTimelinePlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageTimelinePlugin", targets: ["MessageTimelinePlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "MessageTimelinePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)
