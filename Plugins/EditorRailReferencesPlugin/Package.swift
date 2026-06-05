// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRailReferencesPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorRailReferencesPlugin",
            targets: ["EditorRailReferencesPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorRailReferencesPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md", "Sources/Views"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorRailReferencesPluginTests",
            dependencies: ["EditorRailReferencesPlugin"],
            path: "Tests"
        )
    ]
)
