// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToast",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginToast", targets: ["PluginToast"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderToast"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginToast",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderToast", package: "ProviderToast"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginToast"
        ),
        .testTarget(name: "PluginToastTests", dependencies: ["PluginToast"]),
    ]
)
