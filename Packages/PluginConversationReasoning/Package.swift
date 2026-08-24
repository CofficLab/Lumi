// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationReasoning",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationReasoningPlugin",
            targets: ["ConversationReasoningPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationReasoningPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources"
        ,
            resources: [.process("../Resources/Localizable.xcstrings")]),
        .testTarget(
            name: "ConversationReasoningPluginTests",
            dependencies: ["ConversationReasoningPlugin"],
            path: "Tests"
        )
    ]
)
