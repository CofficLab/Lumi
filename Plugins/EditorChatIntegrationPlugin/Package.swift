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
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorChatIntegrationPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorChatIntegrationPluginTests",
            dependencies: [
                "EditorChatIntegrationPlugin",
                .product(name: "EditorService", package: "EditorService"),
            ],
            path: "Tests"
        )
    ]
)
