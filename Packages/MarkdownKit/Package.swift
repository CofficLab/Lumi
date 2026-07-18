// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownKit",
    defaultLocalization: "en",
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
        ),
        .library(
            name: "MarkdownKitTesting",
            targets: ["MarkdownKitTesting"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
        .package(url: "https://github.com/lukilabs/beautiful-mermaid-swift", from: "1.0.0"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "MarkdownKitCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
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
            name: "MarkdownKit",
            dependencies: [
                "MarkdownKitCore",
                .product(name: "BeautifulMermaid", package: "beautiful-mermaid-swift"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
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
            name: "MarkdownKitTesting",
            dependencies: ["MarkdownKit"],
            path: "Tests/MarkdownKitTesting"
        ),
        .testTarget(
            name: "MarkdownKitCoreTests",
            dependencies: ["MarkdownKitCore"],
            path: "Tests/MarkdownKitCoreTests"
        ),
        .testTarget(
            name: "MarkdownKitTests",
            dependencies: ["MarkdownKit", "MarkdownKitTesting"],
            path: "Tests/MarkdownKitTests"
        )
    ]
)
