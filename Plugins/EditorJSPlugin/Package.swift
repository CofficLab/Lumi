// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorJSPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorJSPlugin",
            targets: ["EditorJSPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorTextView"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorJSPlugin",
            dependencies: [
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorJSPluginTests",
            dependencies: ["EditorJSPlugin"],
            path: "Tests"
        )
    ]
)
