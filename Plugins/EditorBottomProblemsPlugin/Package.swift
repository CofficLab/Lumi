// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorBottomProblemsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorBottomProblemsPlugin",
            targets: ["EditorBottomProblemsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorBottomProblemsPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorBottomProblemsPluginTests",
            dependencies: ["EditorBottomProblemsPlugin"],
            path: "Tests"
        )
    ]
)
