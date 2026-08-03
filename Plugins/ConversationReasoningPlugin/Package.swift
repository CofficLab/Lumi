// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationReasoningPlugin",
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
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationReasoningPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
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
