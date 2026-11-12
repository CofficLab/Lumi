// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitEditorLanguageRuntime",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(
            name: "EditorLanguageRuntime",
            targets: ["EditorLanguageRuntime"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", from: "0.25.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "EditorLanguageRuntime",
            dependencies: [
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/KitEditorLanguageRuntime",
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorLanguageRuntimeTests",
            dependencies: ["EditorLanguageRuntime"],
            path: "Tests"
        ),
    ]
)
