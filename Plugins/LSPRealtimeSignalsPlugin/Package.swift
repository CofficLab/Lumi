// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LSPRealtimeSignalsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LSPRealtimeSignalsPlugin",
            targets: ["LSPRealtimeSignalsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LSPRealtimeSignalsPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LSPRealtimeSignalsPluginTests",
            dependencies: [
                "LSPRealtimeSignalsPlugin",
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
            ],
            path: "Tests"
        )
    ]
)
