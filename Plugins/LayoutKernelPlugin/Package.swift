// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LayoutKernelPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LayoutKernelPlugin", targets: ["LayoutKernelPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LayoutKernelPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        ),
    ]
)