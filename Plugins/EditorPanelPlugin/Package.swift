// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorPanelPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorPanelPlugin",
            targets: ["EditorPanelPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../EditorPreviewPlugin"),
        .package(path: "../EditorStickySymbolBarPlugin"),
        .package(path: "../EditorTerminalPlugin"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.9.0"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
    ],
    targets: [
        .target(
            name: "EditorPanelPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorTerminalPlugin", package: "EditorTerminalPlugin"),
                .product(name: "EditorPreviewPlugin", package: "EditorPreviewPlugin"),
                .product(name: "EditorStickySymbolBarPlugin", package: "EditorStickySymbolBarPlugin"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
    ]
)
