// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRailProblemsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorRailProblemsPlugin",
            targets: ["EditorRailProblemsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../EditorBottomProblemsPlugin"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorRailProblemsPlugin",
            dependencies: [
                .product(name: "EditorBottomProblemsPlugin", package: "EditorBottomProblemsPlugin"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorRailProblemsPluginTests",
            dependencies: ["EditorRailProblemsPlugin"],
            path: "Tests"
        )
    ]
)
