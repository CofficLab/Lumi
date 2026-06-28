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
    targets: [
        .target(
            name: "EditorChatInputKit",
            path: "Sources"
        ),
        .testTarget(
            name: "EditorChatInputKitTests",
            dependencies: ["EditorChatInputKit"],
            path: "Tests"
        )
    ]
)
