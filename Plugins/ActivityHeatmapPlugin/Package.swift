// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ActivityHeatmapPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ActivityHeatmapPlugin",
            targets: ["ActivityHeatmapPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ActivityHeatmapPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ActivityHeatmapPluginTests",
            dependencies: [
                "ActivityHeatmapPlugin",
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Tests"
        )
    ]
)
