// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LegacyDataPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LegacyDataPlugin", targets: ["LegacyDataPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LegacyDataPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        ),
        .testTarget(
            name: "LegacyDataPluginTests",
            dependencies: ["LegacyDataPlugin", "LumiKernel"],
            path: "Tests/LegacyDataPluginTests"
        ),
    ]
)
