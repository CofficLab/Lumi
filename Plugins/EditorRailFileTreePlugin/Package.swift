// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRailFileTreePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorRailFileTreePlugin",
            targets: ["EditorRailFileTreePlugin"]
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
            name: "EditorRailFileTreePlugin",
            dependencies: [
                .product(name: "FileTreeKit", package: "FileTreeKit"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorRailFileTreePluginTests",
            dependencies: ["EditorRailFileTreePlugin"],
            path: "Tests"
        )
    ]
)
