// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginNetto",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "PluginNetto",
            targets: ["NettoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderWorkspace"),
        .package(path: "../KitSuperLog")
    ],
    targets: [
.target(
            name: "NettoPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
                .product(name: "KitSuperLog", package: "KitSuperLog")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "NettoPluginTests",
            dependencies: [.target(name: "NettoPlugin")],
            path: "Tests"
        )
    ]
)
