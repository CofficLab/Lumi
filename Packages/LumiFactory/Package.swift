// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumiFactory",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiFactory", targets: ["LumiFactory"]),
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
        .package(path: "../SuperLogKit"),
        .package(path: "../../Plugins/StoragePlugin"),
        .package(path: "../../Plugins/ProjectPlugin"),
    ],
    targets: [
        .target(
            name: "LumiFactory",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "StoragePlugin", package: "StoragePlugin"),
                .product(name: "ProjectPlugin", package: "ProjectPlugin"),
            ]
        ),
    ]
)