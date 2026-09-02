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
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
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
