// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFiles",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginProjectFiles", targets: ["PluginProjectFiles"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "PluginProjectFiles",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
            ],
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "PluginProjectFilesTests",
            dependencies: [
                "PluginProjectFiles",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
            ]
        ),
    ]
)
