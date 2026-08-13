// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StoragePlugin",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "StoragePlugin", targets: ["StoragePlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "StoragePlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: ".",
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
    ]
)
