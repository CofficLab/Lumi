// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginFileLog",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginFileLog",
            targets: ["PluginFileLog"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderDiagnostics"),
        .package(path: "../ProviderUninstall"),
    ],
    targets: [
        .target(
            name: "PluginFileLog",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderDiagnostics", package: "ProviderDiagnostics"),
                .product(name: "ProviderUninstall", package: "ProviderUninstall"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ],
            path: "Sources/PluginFileLog"
        ),
        .testTarget(
            name: "PluginFileLogTests",
            dependencies: [
                "PluginFileLog",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderDiagnostics", package: "ProviderDiagnostics"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ],
            path: "Tests/PluginFileLogTests"
        )
    ]
)
