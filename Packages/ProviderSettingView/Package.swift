// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderSettingView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderSettingView",
            targets: ["ProviderSettingView"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "ProviderSettingView",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources/ProviderSettingView",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ProviderSettingViewTests",
            dependencies: ["ProviderSettingView"]
        )
    ]
)
