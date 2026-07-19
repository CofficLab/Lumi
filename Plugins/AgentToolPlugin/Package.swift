// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentToolPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentToolPlugin", targets: ["AgentToolPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "AgentToolPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        ),
    ]
)