// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginNetto",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "PluginNetto",
            targets: ["NettoPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../KitSuperLog")
    ],
    targets: [
.target(
            name: "NettoPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
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
