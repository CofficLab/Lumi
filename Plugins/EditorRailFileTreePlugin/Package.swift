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
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/FileTreeKit"),
        .package(url: "https://github.com/nookery/Libgit2swift", .branch("main")),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorRailFileTreePlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "FileTreeKit", package: "FileTreeKit"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
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
