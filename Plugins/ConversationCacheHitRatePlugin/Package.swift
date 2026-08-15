// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationCacheHitRatePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationCacheHitRatePlugin",
            targets: ["ConversationCacheHitRatePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationCacheHitRatePlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        )
    ]
)
