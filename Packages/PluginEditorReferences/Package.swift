// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorReferences",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorReferencesPlugin",
            targets: ["EditorReferencesPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorReferencesPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorReferencesPluginTests",
            dependencies: ["EditorReferencesPlugin"],
            path: "Tests"
        )
    ]
)
