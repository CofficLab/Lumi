// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationTitlePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationTitlePlugin",
            targets: ["ConversationTitlePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "ConversationTitlePlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: ".",
            exclude: [
                "Tests",
                "README.md",
                "Sources/TitleOrchestrator.swift",
                "Sources/ConversationTitleRuntimeBridge.swift",
                "Sources/ConversationTitleEventObserver.swift",
                "Sources/Services",
                "Sources/Tools",
                "Sources/Policy",
            ],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ConversationTitlePluginTests",
            dependencies: ["ConversationTitlePlugin"],
            path: "Tests"
        )
    ]
)
