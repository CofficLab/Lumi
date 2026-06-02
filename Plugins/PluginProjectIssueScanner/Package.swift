// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectIssueScanner",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginProjectIssueScanner",
            targets: ["PluginProjectIssueScanner"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ModelRouterKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginProjectIssueScanner",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit",
            path: "Sources"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ModelRouterKit", package: "ModelRouterKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginProjectIssueScannerTests",
            dependencies: ["PluginProjectIssueScanner"],
            path: "Tests"
        )
    ]
)
