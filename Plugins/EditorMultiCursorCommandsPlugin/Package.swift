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
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorMultiCursorCommandsPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorMultiCursorCommandsPluginTests",
            dependencies: ["EditorMultiCursorCommandsPlugin"],
            path: "Tests"
        )
    ]
)
