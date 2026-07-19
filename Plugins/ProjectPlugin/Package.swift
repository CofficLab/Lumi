// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProjectPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProjectPlugin", targets: ["ProjectPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ProjectPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        ),
    ]
)