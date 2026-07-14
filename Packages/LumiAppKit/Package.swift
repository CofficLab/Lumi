// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumiAppKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiAppKit",
            targets: ["LumiAppKit"]
        )
    ],
    dependencies: [
        // 本地包依赖
        .package(name: "LumiCoreKit", path: "../LumiCoreKit"),
        .package(name: "LumiChatKit", path: "../LumiChatKit"),
        .package(name: "LumiUI", path: "../LumiUI"),
        .package(name: "SuperLogKit", path: "../SuperLogKit"),
        .package(name: "LumiPluginRegistry", path: "../LumiPluginRegistry"),
        .package(name: "EditorService", path: "../EditorService"),
        .package(name: "EditorTextView", path: "../EditorTextView"),
        .package(name: "EditorPanelPlugin", path: "../../Plugins/EditorPanelPlugin"),
        // 远程包依赖
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "LumiAppKit",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiPluginRegistry", package: "LumiPluginRegistry"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "EditorPanelPlugin", package: "EditorPanelPlugin"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "MagicAlert", package: "MagicAlert"),
            ],
            path: "Sources/LumiAppKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LumiAppKitTests",
            dependencies: ["LumiAppKit"],
            path: "Tests/LumiAppKitTests"
        )
    ]
)
