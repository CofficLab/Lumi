// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GitPlugin",
            targets: ["GitPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LLMKit"),
        .package(url: "https://github.com/nookery/Libgit2swift", .branch("main")),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(url: "https://github.com/nookery/MagicDiffView", .branch("main")),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "GitPlugin",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MagicDiffView", package: "MagicDiffView"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "GitPluginTests",
            dependencies: ["GitPlugin"],
            path: "Tests"
        )
    ]
)
