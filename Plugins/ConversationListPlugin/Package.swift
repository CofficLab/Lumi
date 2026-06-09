// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationListPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationListPlugin",
            targets: ["ConversationListPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "ConversationListPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: ".",
            exclude: [
                "Tests",
                "README.md",
                "Sources/Views",
                "Sources/Tools",
            ],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ConversationListPluginTests",
            dependencies: ["ConversationListPlugin"],
            path: "Tests"
        )
    ]
)
