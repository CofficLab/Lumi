// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorMarkdownPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorMarkdownPlugin",
            targets: ["EditorMarkdownPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/CodeEditLanguages"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorMarkdownPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
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
            name: "EditorMarkdownPluginTests",
            dependencies: ["EditorMarkdownPlugin"],
            path: "Tests"
        )
    ]
)
