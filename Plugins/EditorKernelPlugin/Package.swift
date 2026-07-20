// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorKernelPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EditorKernelPlugin", targets: ["EditorKernelPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorKernelPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ]
        ),
    ]
)