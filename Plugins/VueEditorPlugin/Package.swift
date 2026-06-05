// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VueEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VueEditorPlugin",
            targets: ["VueEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/EditorService"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "VueEditorPlugin",
            dependencies: [
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "VueEditorPluginTests",
            dependencies: ["VueEditorPlugin"],
            path: "Tests"
        )
    ]
)
