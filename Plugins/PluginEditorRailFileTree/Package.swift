// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorRailFileTree",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorRailFileTree",
            targets: ["PluginEditorRailFileTree"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/FileTreeKit"),
        .package(url: "https://github.com/nookery/Libgit2swift", .branch("main")),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorRailFileTree",
            dependencies: [
                .product(name: "FileTreeKit", package: "FileTreeKit"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorRailFileTree",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorRailFileTreeTests",
            dependencies: ["PluginEditorRailFileTree"],
            path: "Tests"
        )
    ]
)
