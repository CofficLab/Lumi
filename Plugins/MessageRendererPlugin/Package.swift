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
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/CodeEditLanguages"),
        .package(path: "../../Packages/LumiCodeEditSourceEditor"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit"),
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", .upToNextMajor(from: "0.9.0")),
    ],
    targets: [
        .target(
            name: "MessageRendererPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MessageRendererPluginTests",
            dependencies: ["MessageRendererPlugin"],
            path: "Tests"
        )
    ]
)
