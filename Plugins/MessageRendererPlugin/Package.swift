// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageRendererPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MessageRendererPlugin",
            targets: ["MessageRendererPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit"),
    ],
    targets: [
        .target(
            name: "MessageRendererPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
            ],
            path: ".",
            exclude: [
                "Tests",
                "README.md",
                "Sources/Components",
                "Sources/Message",
                "Sources/MessageComponent",
                "Sources/Renderers",
                "Sources/MessageRendererRuntime.swift",
            ],
            sources: [
                "Sources/MessageRendererPlugin.swift",
                "Sources/Views/CoreMessageViews.swift",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MessageRendererPluginTests",
            dependencies: [
                "MessageRendererPlugin",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
