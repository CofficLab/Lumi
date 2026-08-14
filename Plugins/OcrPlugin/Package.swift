// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OcrPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OcrPlugin", targets: ["OcrPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "OcrPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/OcrPlugin"
        ),
        .testTarget(
            name: "OcrPluginTests",
            dependencies: [
                "OcrPlugin",
                .product(name: "KernelLumi", package: "KernelLumi"),
            ],
            path: "Tests/OcrPluginTests"
        ),
    ]
)
