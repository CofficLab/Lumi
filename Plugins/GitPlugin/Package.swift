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
        .package(url: "https://github.com/nookery/LibGit2Swift", .branch("main")),
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/EditorContracts"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
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
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MagicDiffView", package: "MagicDiffView"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "GitPluginTests",
            dependencies: [
                "GitPlugin",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
            ],
            path: "Tests"
        )
    ]
)
