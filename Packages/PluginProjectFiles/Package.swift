// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFiles",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginProjectFiles", targets: ["PluginProjectFiles"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRootView"),
    ],
    targets: [
        .target(
            name: "PluginProjectFiles",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
            ],
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "PluginProjectFilesTests",
            dependencies: [
                "PluginProjectFiles",
                .product(name: "ProviderProject", package: "ProviderProject"),
            ]
        ),
    ]
)
