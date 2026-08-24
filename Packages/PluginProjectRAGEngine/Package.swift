// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectRAGEngine",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginProjectRAGEngine",
            targets: ["ProjectRAGPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
        .package(path: "../ProviderIdleTime"),
        .package(path: "../ProviderProject"),
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
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Sources",
            exclude: [
                "CSQLite",
            ],
            resources: [
                .copy("../Resources/vec0.dylib")
            ]
        ),
        .testTarget(
            name: "ProjectRAGPluginTests",
            dependencies: ["ProjectRAGPlugin"],
            path: "Tests"
        )
    ]
)
