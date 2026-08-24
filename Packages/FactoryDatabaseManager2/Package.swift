// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryDatabaseManager2",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FactoryDatabaseManager2", targets: ["FactoryDatabaseManager2"])],
    dependencies: [
        .package(path: "../FactoryLumi2"),
        .package(path: "../KernelCore"),
        .package(path: "../PluginEditorHost"),
        .package(name: "PluginDatabaseManager", path: "../../Plugins/DatabaseManagerPlugin"),
        .package(path: "../ProviderExternalFile"),
    ],
    targets: [
        .target(
            name: "FactoryDatabaseManager2",
            dependencies: [
                .product(name: "FactoryLumi2", package: "FactoryLumi2"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "PluginEditorHost", package: "PluginEditorHost"),
                .product(name: "PluginDatabaseManager", package: "PluginDatabaseManager"),
                .product(name: "ProviderExternalFile", package: "ProviderExternalFile"),
            ]
        ),
        .testTarget(
            name: "FactoryDatabaseManager2Tests",
            dependencies: [
                "FactoryDatabaseManager2",
                .product(name: "KernelCore", package: "KernelCore"),
            ]
        ),
    ]
)
