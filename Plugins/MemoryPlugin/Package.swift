// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoryPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MemoryPlugin",
            targets: ["MemoryPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "MemoryPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "MemoryPluginTests",
            dependencies: ["MemoryPlugin"],
            path: "Tests"
        )
    ]
)
