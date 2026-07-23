// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageRendererPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "MessageRendererPlugin",
            targets: ["MessageRendererPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiCoreMessage"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit"),
    ],
    targets: [
        .target(
            name: "MessageRendererPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
            ],
            path: "Sources/MessageRendererPlugin",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "MessageRendererPluginTests",
            dependencies: [
                "MessageRendererPlugin",
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
            ],
            path: "Tests"
        )
    ]
)
