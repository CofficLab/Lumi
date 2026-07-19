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
    ],
    targets: [
        .target(
            name: "StoragePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
            ]
        ),
    ]
)