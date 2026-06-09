// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSwiftSelectionCodeActionPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSwiftSelectionCodeActionPlugin",
            targets: ["EditorSwiftSelectionCodeActionPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorSwiftSelectionCodeActionPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorSwiftSelectionCodeActionPluginTests",
            dependencies: ["EditorSwiftSelectionCodeActionPlugin"],
            path: "Tests"
        )
    ]
)
