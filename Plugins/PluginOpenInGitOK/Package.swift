// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInGitOK",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginOpenInGitOK",
            targets: ["PluginOpenInGitOK"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginOpenInGitOK",
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
            name: "PluginOpenInGitOKTests",
            dependencies: ["PluginOpenInGitOK"],
            path: "Tests"
        )
    ]
)
