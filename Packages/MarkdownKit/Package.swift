// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MarkdownKitCore",
            targets: ["MarkdownKitCore"]
        ),
        .library(
            name: "MarkdownKit",
            targets: ["MarkdownKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
        .package(url: "https://github.com/lukilabs/beautiful-mermaid-swift", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MarkdownKitCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: ".",
            exclude: [
                "Package.swift",
                "Mermaid",
                "Tests",
                "Views"
            ],
            sources: [
                "Models",
                "Parsers"
            ]
        ),
        .target(
            name: "MarkdownKit",
            dependencies: [
                "MarkdownKitCore",
                .product(name: "BeautifulMermaid", package: "beautiful-mermaid-swift")
            ],
            path: ".",
            exclude: [
                "Package.swift",
                "Tests",
                "Models",
                "Parsers"
            ],
            sources: [
                "Mermaid",
                "Views"
            ]
        ),
        .testTarget(
            name: "MarkdownKitCoreTests",
            dependencies: ["MarkdownKitCore"],
            path: "Tests/MarkdownKitCoreTests"
        ),
        .testTarget(
            name: "MarkdownKitTests",
            dependencies: ["MarkdownKit"],
            path: "Tests/MarkdownKitTests"
        )
    ]
)
