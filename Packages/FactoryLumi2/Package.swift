// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FactoryLumi2",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FactoryLumi2", targets: ["FactoryLumi2"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LumiUI"),
        .package(path: "../PluginDevice"),
        .package(path: "../PluginLogoCoffic"),
        .package(path: "../PluginSettingGeneral"),
        .package(path: "../PluginToolbarSettings"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderMenuBar"),
        .package(path: "../ProviderLogo"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToast"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "FactoryLumi2",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "PluginDevice", package: "PluginDevice"),
                .product(name: "PluginLogoCoffic", package: "PluginLogoCoffic"),
                .product(name: "PluginSettingGeneral", package: "PluginSettingGeneral"),
                .product(name: "PluginToolbarSettings", package: "PluginToolbarSettings"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderMenuBar", package: "ProviderMenuBar"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "ProviderNetwork", package: "ProviderNetwork"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToast", package: "ProviderToast"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ],
            path: "Sources/FactoryLumi2"
        ),
        .testTarget(
            name: "FactoryLumi2Tests",
            dependencies: ["FactoryLumi2"]
        )
    ]
)
