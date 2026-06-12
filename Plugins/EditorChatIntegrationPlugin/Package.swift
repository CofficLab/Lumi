// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorChatIntegrationPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorChatIntegrationPlugin",
            targets: ["EditorChatIntegrationPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorCodeEditTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorChatIntegrationPlugin",
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
            name: "EditorChatIntegrationPluginTests",
            dependencies: [
                "EditorChatIntegrationPlugin",
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
