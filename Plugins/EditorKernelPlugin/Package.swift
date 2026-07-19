// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EditorKernelPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EditorKernelPlugin", targets: ["EditorKernelPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorKernelPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        ),
    ]
)