// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToast",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginToast", targets: ["PluginToast"])],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../ProviderToast"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginToast",
            dependencies: [
                "KitSuperLog",
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
