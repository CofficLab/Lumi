// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolManagerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ToolManagerPlugin", targets: ["ToolManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/FileSystemKit"),
    ],
    targets: [
        .target(
            name: "ToolManagerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "FileSystemKit", package: "FileSystemKit"),
            ],
            path: "Sources/ToolManagerPlugin",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
    ]
)