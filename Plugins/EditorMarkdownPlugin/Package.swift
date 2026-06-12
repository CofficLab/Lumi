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
        .package(path: "../../Packages/EditorLanguages"),
        .package(path: "../../Packages/EditorTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorMarkdownPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorLanguages", package: "EditorLanguages"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorMarkdownPluginTests",
            dependencies: ["EditorMarkdownPlugin"],
            path: "Tests"
        )
    ]
)
