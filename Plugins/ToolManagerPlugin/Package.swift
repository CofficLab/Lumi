// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ToolManagerPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ToolManagerPlugin", targets: ["ToolManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ToolManagerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        ),
    ]
)