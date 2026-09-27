// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToast",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginToast", targets: ["PluginToast"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderToast"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "PluginToast",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderToast", package: "ProviderToast"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginToast"
        ),
        .testTarget(
            name: "PluginToastTests",
            dependencies: [
                "PluginToast",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: "Tests/PluginToastTests"
        ),
    ]
)
