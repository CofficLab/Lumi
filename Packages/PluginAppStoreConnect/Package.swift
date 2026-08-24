// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppStoreConnect",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppStoreConnectPlugin",
            targets: ["AppStoreConnectPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
        .package(path: "../HTMLPreviewKit"),
        .package(path: "../AppStorePromoKit"),
    ],
    targets: [
        .target(
            name: "AppStoreConnectPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
                .product(name: "AppStorePromoKit", package: "AppStorePromoKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "AppStoreConnectPluginTests",
            dependencies: ["AppStoreConnectPlugin"],
            path: "Tests"
        )
    ]
)
