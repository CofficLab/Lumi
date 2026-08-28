// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderRootView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderRootView",
            targets: ["ProviderRootView"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderWorkspace"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "ProviderRootView",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/ProviderRootView",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ProviderRootViewTests",
            dependencies: [
                "ProviderRootView",
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
            ]
        )
    ]
)
