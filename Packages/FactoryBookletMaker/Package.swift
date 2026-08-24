// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryBookletMaker",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FactoryBookletMaker", targets: ["FactoryBookletMaker"]),
    ],
    dependencies: [
        .package(path: "../FactoryLumi"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderPluginManaging"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToast"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderWorkspace"),
        .package(name: "PluginBookletMaker", path: "../PluginBookletMaker"),
    ],
    targets: [
        .target(
            name: "FactoryBookletMaker",
            dependencies: [
                .product(name: "FactoryLumi", package: "FactoryLumi"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderNetwork", package: "ProviderNetwork"),
                .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToast", package: "ProviderToast"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
                .product(name: "PluginBookletMaker", package: "PluginBookletMaker"),
            ],
            path: "Sources/FactoryBookletMaker"
        ),
        .testTarget(
            name: "FactoryBookletMakerTests",
            dependencies: ["FactoryBookletMaker"],
            path: "Tests/FactoryBookletMakerTests"
        ),
    ]
)
