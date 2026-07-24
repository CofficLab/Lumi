// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectRAGPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProjectRAGPlugin",
            targets: ["ProjectRAGPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "CSQLite",
            path: "Sources/CSQLite",
            publicHeadersPath: "include",
            cSettings: [
                .define("SQLITE_ENABLE_LOAD_EXTENSION")
            ]
        ),
        .target(
            name: "ProjectRAGPlugin",
            dependencies: [
                "CSQLite",
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            exclude: ["CSQLite"],
            resources: [
                .process("../Resources/Localizable.xcstrings"),
                .copy("Resources/vec0.dylib")
            ]
        ),
        .testTarget(
            name: "ProjectRAGPluginTests",
            dependencies: ["ProjectRAGPlugin"],
            path: "Tests"
        )
    ]
)