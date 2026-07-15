// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorChatInputKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorChatInputKit",
            targets: ["EditorChatInputKit"]
        )
    ],
    dependencies: [
        .package(path: "../LumiLocalizationKit"),
    ],

    targets: [
        .target(
            name: "EditorChatInputKit",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "EditorChatInputKitTests",
            dependencies: ["EditorChatInputKit"],
            path: "Tests"
        )
    ]
)
