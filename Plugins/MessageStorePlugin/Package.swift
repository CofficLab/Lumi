// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageStorePlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageStorePlugin", targets: ["MessageStorePlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiCoreMessage"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "MessageStorePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)
