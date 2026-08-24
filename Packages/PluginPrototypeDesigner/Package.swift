// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPrototypeDesigner",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PrototypeDesignerPlugin",
            targets: ["PrototypeDesignerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PrototypeDesignerPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        )
    ]
)
