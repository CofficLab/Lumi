// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginVueEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginVueEditor",
            targets: ["PluginVueEditor"]
        )
    ],
    dependencies: [
        .package(path: "../CodeEditTextView"),
        .package(path: "../EditorService"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginVueEditor",
            dependencies: [
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginVueEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginVueEditorTests",
            dependencies: ["PluginVueEditor"],
            path: "Tests/PluginVueEditorTests"
        )
    ]
)
