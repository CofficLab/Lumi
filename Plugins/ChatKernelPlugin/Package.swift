// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChatKernelPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ChatKernelPlugin", targets: ["ChatKernelPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ChatKernelPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        ),
    ]
)