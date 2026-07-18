// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolCorePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ToolCorePlugin",
            targets: ["ToolCorePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/FileSystemKit"),
    ],
    targets: [
        .target(
            name: "ToolCorePlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "FileSystemKit", package: "FileSystemKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ToolCorePluginTests",
            dependencies: ["ToolCorePlugin"],
            path: "Tests"
        )
    ]
)
