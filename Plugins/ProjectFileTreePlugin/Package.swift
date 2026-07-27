// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectFileTreePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ProjectFileTreePlugin",
            targets: ["ProjectFileTreePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/FileSystemKit"),
        .package(url: "https://github.com/nookery/LibGit2Swift", .branch("main")),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ProjectFileTreePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
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
