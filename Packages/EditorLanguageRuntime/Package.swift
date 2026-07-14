// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorLanguageRuntime",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "EditorLanguageRuntime",
            targets: ["EditorLanguageRuntime"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "EditorLanguageRuntime",
            dependencies: [
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorLanguageRuntimeTests",
            dependencies: ["EditorLanguageRuntime"],
            path: "Tests"
        ),
    ]
)
