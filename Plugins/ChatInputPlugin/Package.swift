// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatInputPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatInputPlugin",
            targets: ["ChatInputPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorChatInputKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ChatInputPlugin",
            dependencies: [
                .product(name: "EditorChatInputKit", package: "EditorChatInputKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ChatInputPluginTests",
            dependencies: [
                "ChatInputPlugin",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
