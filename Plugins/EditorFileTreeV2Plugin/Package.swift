// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorFileTreeV2Plugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorFileTreeV2Plugin",
            targets: ["EditorFileTreeV2Plugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/FileTreeKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../EditorFileTreePlugin"),
        .package(url: "https://github.com/nookery/Libgit2swift", .branch("main")),
    ],
    targets: [
        .target(
            name: "EditorFileTreeV2Plugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "FileTreeKit", package: "FileTreeKit"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "EditorFileTreePlugin", package: "EditorFileTreePlugin"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorFileTreeV2PluginTests",
            dependencies: [
                "EditorFileTreeV2Plugin",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Tests"
        )
    ]
)
