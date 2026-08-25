// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBookletMaker",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "PluginBookletMaker",
            targets: ["BookletMakerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderWorkspace"),
        .package(path: "../KitSuperLog")
    ],
    targets: [
        .target(
            name: "BookletMakerPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
                .product(name: "KitSuperLog", package: "KitSuperLog")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BookletMakerPluginTests",
            dependencies: [.target(name: "BookletMakerPlugin")],
            path: "Tests"
        )
    ]
)
