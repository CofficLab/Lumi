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
        .package(path: "../../Packages/FileSystemKit"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(url: "https://github.com/nookery/LibGit2Swift", .branch("main")),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "EditorFileTreeV2Plugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "FileSystemKit", package: "FileSystemKit"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "MagicAlert", package: "MagicAlert"),
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
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Tests"
        )
    ]
)
