// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageListAppKitPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageListAppKitPlugin", targets: ["MessageListAppKitPlugin"]),
    ],
    dependencies: [
        // Core kit packages (sibling under Packages/).
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        // Markdown block parsing only — the SwiftUI `MarkdownKit` product is
        // intentionally NOT used (per the implementation plan).
        .package(path: "../../Packages/MarkdownKit"),
        // Mermaid renderer is consumed directly so this target can import the
        // `BeautifulMermaid` product without pulling in SwiftUI MarkdownKit.
        .package(url: "https://github.com/lukilabs/beautiful-mermaid-swift", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MessageListAppKitPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "MarkdownKitCore", package: "MarkdownKit"),
                .product(name: "BeautifulMermaid", package: "beautiful-mermaid-swift"),
            ],
            path: "Sources",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MessageListAppKitPluginTests",
            dependencies: ["MessageListAppKitPlugin"],
            path: "Tests"
        ),
    ]
)
