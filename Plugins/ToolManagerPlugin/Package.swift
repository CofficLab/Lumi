// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolManagerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ToolManagerPlugin", targets: ["ToolManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/FileSystemKit"),
    ],
    targets: [
        .target(
            name: "ToolManagerPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
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
        .testTarget(
            name: "ToolManagerPluginTests",
            dependencies: ["ToolManagerPlugin"],
            path: "Tests/ToolManagerPluginTests"
        ),
    ]
)
