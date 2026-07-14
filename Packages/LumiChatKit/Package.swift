// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiChatKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiChatKit",
            targets: ["LumiChatKit"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../ModelRouterKit"),
        .package(path: "../EditorChatInputKit"),
    ],
    targets: [
        .target(
            name: "LumiChatKit",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "ModelRouterKit", package: "ModelRouterKit"),
                .product(name: "EditorChatInputKit", package: "EditorChatInputKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "LumiChatKitTests",
            dependencies: ["LumiChatKit"],
            path: "Tests"
        )
    ]
)
