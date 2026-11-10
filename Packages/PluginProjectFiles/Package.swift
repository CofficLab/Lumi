// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFiles",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginProjectFiles", targets: ["PluginProjectFiles"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiProviders"),
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
