// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectFilesPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProjectFilesPlugin",
            targets: ["ProjectFilesPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ProjectFilesPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ProjectFilesPluginTests",
            dependencies: [
                "ProjectFilesPlugin",
            ],
            path: "Tests"
        )
    ]
)
