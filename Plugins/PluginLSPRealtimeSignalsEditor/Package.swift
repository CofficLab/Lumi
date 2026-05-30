// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLSPRealtimeSignalsEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLSPRealtimeSignalsEditor",
            targets: ["PluginLSPRealtimeSignalsEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCodeEditSourceEditor"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLSPRealtimeSignalsEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLSPRealtimeSignalsEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPRealtimeSignalsEditorTests",
            dependencies: ["PluginLSPRealtimeSignalsEditor"],
            path: "Tests/PluginLSPRealtimeSignalsEditorTests"
        )
    ]
)
