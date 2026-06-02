// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatInputEditorKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatInputEditorKit",
            targets: ["ChatInputEditorKit"]
        )
    ],
    targets: [
        .target(
            name: "ChatInputEditorKit",
            path: "Sources/ChatInputEditorKit"
        ),
        .testTarget(
            name: "ChatInputEditorKitTests",
            dependencies: ["ChatInputEditorKit"],
            path: "Tests"
        )
    ]
)
