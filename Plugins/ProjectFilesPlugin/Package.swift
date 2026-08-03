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
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ProjectFilesPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources"
        ,
            resources: [.process("../Resources/Localizable.xcstrings")]),
        .testTarget(
            name: "ProjectFilesPluginTests",
            dependencies: [
                "ProjectFilesPlugin",
            ],
            path: "Tests"
        )
    ]
)
