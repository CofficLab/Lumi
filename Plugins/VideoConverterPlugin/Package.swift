// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VideoConverterPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "VideoConverterPlugin",
            targets: ["VideoConverterPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
.target(
            name: "VideoConverterPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "VideoConverterPluginTests",
            dependencies: [.target(name: "VideoConverterPlugin")],
            path: "Tests"
        )
    ]
)