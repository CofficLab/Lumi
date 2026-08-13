// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginManagerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginManagerPlugin",
            targets: ["PluginManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "PluginManagerPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources/PluginManagerPlugin",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
    ]
)
