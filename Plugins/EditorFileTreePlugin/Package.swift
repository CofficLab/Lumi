// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorFileTreePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorFileTreePlugin",
            targets: ["EditorFileTreePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/FileSystemKit"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(url: "https://github.com/nookery/LibGit2Swift", .branch("main")),
    ],
    targets: [
        .target(
            name: "EditorFileTreePlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "FileSystemKit", package: "FileSystemKit"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorFileTreePluginTests",
            dependencies: [
                "EditorFileTreePlugin",
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),            ],
            path: "Tests"
        )
    ]
)
