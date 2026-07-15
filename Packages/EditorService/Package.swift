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
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../EditorKernel"),
        .package(path: "../EditorSource"),
        .package(path: "../EditorTextView"),
        .package(path: "../EditorLanguageRuntime"),
        .package(path: "../ShellKit"),
        .package(path: "../SuperLogKit"),
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
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "EditorSource", package: "EditorSource"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "LanguageClient", package: "LanguageClient"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "MagicAlert", package: "MagicAlert"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
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
                .product(name: "EditorSource", package: "EditorSource"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            ],
            path: "Tests"
        ),
    ]
)
