// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryDatabaseManager",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FactoryDatabaseManager", targets: ["FactoryDatabaseManager"])],
    dependencies: [
        .package(path: "../FactoryLumi"),
        .package(path: "../KernelCore"),
        .package(path: "../PluginCodeEditorHost"),
        .package(name: "PluginDatabaseManager", path: "../PluginDatabaseManager"),
        .package(path: "../ProviderExternalFile"),
    ],
    targets: [
        .target(
            name: "FactoryDatabaseManager",
            dependencies: [
                .product(name: "FactoryLumi", package: "FactoryLumi"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "PluginCodeEditorHost", package: "PluginCodeEditorHost"),
                .product(name: "PluginDatabaseManager", package: "PluginDatabaseManager"),
                .product(name: "ProviderExternalFile", package: "ProviderExternalFile"),
            ]
        ),
        .testTarget(
            name: "FactoryDatabaseManagerTests",
            dependencies: [
                "FactoryDatabaseManager",
                .product(name: "KernelCore", package: "KernelCore"),
            ]
        ),
    ]
)
