// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSource",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSource",
            targets: ["EditorSource"]
        )
    ],
    dependencies: [
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../LUI"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../EditorLanguageRuntime"),
        .package(path: "../SuperLogKit"),
        .package(path: "../EditorKernel"),
    ],
    targets: [
        .target(
            name: "EditorSource",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LUI", package: "LUI"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "EditorKernel", package: "EditorKernel"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorSourceTests",
            dependencies: [
                "EditorSource",
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
            ],
            path: "Tests"
        )
    ]
)
