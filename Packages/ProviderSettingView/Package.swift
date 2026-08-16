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
    ],
    targets: [
        .target(
            name: "ProviderSettingView",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ProviderSettingView"
        ),
        .testTarget(
            name: "ProviderSettingViewTests",
            dependencies: ["ProviderSettingView"]
        )
    ]
)
