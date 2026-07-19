// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationLanguagePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationLanguagePlugin",
            targets: ["ConversationLanguagePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "ConversationLanguagePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ConversationLanguagePluginTests",
            dependencies: ["ConversationLanguagePlugin"],
            path: "Tests"
        )
    ]
)
