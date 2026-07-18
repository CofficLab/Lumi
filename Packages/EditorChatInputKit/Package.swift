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
        .package(path: "../LocalizationKit"),
    ],

    targets: [
        .target(
            name: "EditorChatInputKit",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
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
