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
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/ProviderContentView"),
        .package(path: "../../Packages/ProviderDocsView"),
        .package(path: "../../Packages/ProviderWorkspace"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
.target(
            name: "NettoPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
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
