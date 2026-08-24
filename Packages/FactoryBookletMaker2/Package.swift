// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryBookletMaker2",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FactoryBookletMaker2", targets: ["FactoryBookletMaker2"]),
    ],
    dependencies: [
        .package(path: "../FactoryLumi2"),
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
        .package(path: "../../Plugins/BookletMakerPlugin"),
    ],
    targets: [
        .target(
            name: "FactoryBookletMaker2",
            dependencies: [
                .product(name: "FactoryLumi2", package: "FactoryLumi2"),
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
            path: "Sources/FactoryBookletMaker2"
        ),
        .testTarget(
            name: "FactoryBookletMaker2Tests",
            dependencies: ["FactoryBookletMaker2"],
            path: "Tests/FactoryBookletMaker2Tests"
        ),
    ]
)
