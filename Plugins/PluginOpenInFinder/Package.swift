// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInFinder",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginOpenInFinder",
            targets: ["PluginOpenInFinder"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginOpenInFinder",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit",
            path: "Sources"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginOpenInFinderTests",
            dependencies: ["PluginOpenInFinder"],
            path: "Tests"
        )
    ]
)
