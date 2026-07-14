// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorService",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "EditorService",
            targets: ["EditorService"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../EditorKernel"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../EditorSource"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../EditorTextView"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../EditorLanguageRuntime"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../ShellKit"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LumiLocalizationKit"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", from: "0.25.0"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.9.0"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
    ],
    targets: [
        .target(
            name: "EditorService",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "EditorSource", package: "EditorSource"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LanguageClient", package: "LanguageClient"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "MagicAlert", package: "MagicAlert"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorServiceTests",
            dependencies: [
                "EditorService",
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "EditorSource", package: "EditorSource"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Tests"
        ),
    ]
)
