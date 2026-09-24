// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCodeEditorHost",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginCodeEditorHost", targets: ["PluginCodeEditorHost"])],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../ProviderEditor"),
        .package(path: "../KitEditorKernel"),
        .package(path: "../KitEditorSource"),
        .package(path: "../KitEditorTextView"),
        .package(path: "../KitEditorLanguageRuntime"),
        .package(path: "../KitShell"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.1"),
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", from: "0.25.0"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.9.0"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
    ],
    targets: [
        .target(
            name: "EditorService",
            dependencies: [
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "EditorKernel", package: "KitEditorKernel"),
                .product(name: "EditorSource", package: "KitEditorSource"),
                .product(name: "EditorTextView", package: "KitEditorTextView"),
                .product(name: "EditorLanguageRuntime", package: "KitEditorLanguageRuntime"),
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "LanguageClient", package: "LanguageClient"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "MagicAlert", package: "MagicAlert"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            ],
            path: "Sources/EditorService",
            resources: [.process("Resources")]
        ),
        .target(
            name: "PluginCodeEditorHost",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                "EditorService",
                .product(name: "EditorSource", package: "KitEditorSource"),
                .product(name: "EditorLanguageRuntime", package: "KitEditorLanguageRuntime"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "EditorServiceTests",
            dependencies: [
                "EditorService",
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "EditorKernel", package: "KitEditorKernel"),
                .product(name: "EditorSource", package: "KitEditorSource"),
                .product(name: "EditorLanguageRuntime", package: "KitEditorLanguageRuntime"),
                .product(name: "EditorTextView", package: "KitEditorTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            ],
            path: "Tests/EditorServiceTests"
        ),
        .testTarget(
            name: "PluginCodeEditorHostTests",
            dependencies: [
                "PluginCodeEditorHost",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                "EditorService",
            ]
        ),
    ]
)
