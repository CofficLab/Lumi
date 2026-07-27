// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StoragePlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StoragePlugin", targets: ["StoragePlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "StoragePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        ),
    ]
)