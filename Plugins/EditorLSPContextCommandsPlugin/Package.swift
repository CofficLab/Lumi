// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorLSPContextCommandsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorLSPContextCommandsPlugin",
            targets: ["EditorLSPContextCommandsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorLSPContextCommandsPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            exclude: [
                "EditorLSPContextCommandContributor.swift",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorLSPContextCommandsPluginTests",
            dependencies: ["EditorLSPContextCommandsPlugin"],
            path: "Tests"
        )
    ]
)
