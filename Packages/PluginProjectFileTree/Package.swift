// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFileTree",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ProjectFileTreePlugin",
            targets: ["ProjectFileTreePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../FileSystemKit"),
        .package(url: "https://github.com/nookery/LibGit2Swift", .branch("main")),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ProjectFileTreePlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "FileSystemKit", package: "FileSystemKit"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "MagicAlert", package: "MagicAlert"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
    ]
)
