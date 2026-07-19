// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppStoreConnectPlugin",
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
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/HTMLPreviewKit"),
    ],
    targets: [
        .target(
            name: "AppStoreConnectPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
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
