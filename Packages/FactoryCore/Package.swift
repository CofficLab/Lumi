// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FactoryCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FactoryCore", targets: ["FactoryCore"]),
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../EditorService"),
    ],
    targets: [
        .target(
            name: "FactoryCore",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "EditorService", package: "EditorService"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FactoryCoreTests",
            dependencies: ["FactoryCore"]
        ),
    ]
)
