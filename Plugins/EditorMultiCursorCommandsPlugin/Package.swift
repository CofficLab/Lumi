// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorMultiCursorCommandsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorMultiCursorCommandsPlugin",
            targets: ["EditorMultiCursorCommandsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorCodeEditTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorMultiCursorCommandsPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorCodeEditTextView", package: "EditorCodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorMultiCursorCommandsPluginTests",
            dependencies: ["EditorMultiCursorCommandsPlugin"],
            path: "Tests"
        )
    ]
)
