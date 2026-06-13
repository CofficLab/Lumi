// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorHTMLPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorHTMLPlugin",
            targets: ["EditorHTMLPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorSource"),
        .package(path: "../../Packages/EditorTextView"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorHTMLPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorSource", package: "EditorSource"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorHTMLPluginTests",
            dependencies: ["EditorHTMLPlugin"],
            path: "Tests"
        )
    ]
)
