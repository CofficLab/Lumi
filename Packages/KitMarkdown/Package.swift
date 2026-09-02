// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitMarkdown",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "KitMarkdownCore",
            targets: ["KitMarkdownCore"]
        ),
        .library(
            name: "KitMarkdown",
            targets: ["KitMarkdown"]
        ),
        .library(
            name: "KitMarkdownTesting",
            targets: ["KitMarkdownTesting"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
        .package(url: "https://github.com/lukilabs/beautiful-mermaid-swift", from: "1.0.1"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "KitMarkdownCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: ".",
            exclude: [
                "Package.swift",
                "Mermaid",
                "README.md",
                "Tests",
                "Views",
                "merged.profdata"
            ],
            sources: [
                "Models",
                "Parsers"
            ]
        ),
        .target(
            name: "KitMarkdown",
            dependencies: [
                "KitMarkdownCore",
                .product(name: "BeautifulMermaid", package: "beautiful-mermaid-swift"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: [
                "Package.swift",
                "Tests",
                "Models",
                "Parsers",
                "README.md",
                "merged.profdata"
            ],
            sources: [
                "Mermaid",
                "Views"
            ],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .target(
            name: "KitMarkdownTesting",
            dependencies: ["KitMarkdown"],
            path: "Tests/KitMarkdownTesting"
        ),
        .testTarget(
            name: "KitMarkdownCoreTests",
            dependencies: ["KitMarkdownCore"],
            path: "Tests/KitMarkdownCoreTests"
        ),
        .testTarget(
            name: "KitMarkdownTests",
            dependencies: ["KitMarkdown", "KitMarkdownTesting"],
            path: "Tests/KitMarkdownTests"
        )
    ]
)
