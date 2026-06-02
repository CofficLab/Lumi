// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrewManagerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BrewManagerPlugin",
            targets: ["BrewManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/BrewKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "BrewManagerPlugin",
            dependencies: [
                .product(name: "BrewKit", package: "BrewKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BrewManagerPluginTests",
            dependencies: ["BrewManagerPlugin"],
            path: "Tests"
        )
    ]
)
