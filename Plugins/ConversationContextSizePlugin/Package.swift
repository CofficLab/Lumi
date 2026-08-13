// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationContextSizePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ConversationContextSizePlugin",
            targets: ["ConversationContextSizePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationContextSizePlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources/ConversationContextSizePlugin"
        ,
            resources: [.process("../../Resources/Localizable.xcstrings")])
    ]
)
