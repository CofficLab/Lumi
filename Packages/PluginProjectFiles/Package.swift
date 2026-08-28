// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFiles",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginProjectFiles", targets: ["PluginProjectFiles"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRootView"),
    ],
    targets: [
        .target(
            name: "PluginProjectFiles",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginProjectFilesTests",
            dependencies: ["PluginProjectFiles"]
        ),
    ]
)
