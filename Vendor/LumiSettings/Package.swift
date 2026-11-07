// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiSettings",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ProviderSettingView", targets: ["ProviderSettingView"]),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "ProviderSettingView",
            dependencies: [.product(name: "LumiUI", package: "LumiUI")]
        ),
        .testTarget(
            name: "ProviderSettingViewTests",
            dependencies: ["ProviderSettingView"]
        ),
    ]
)
