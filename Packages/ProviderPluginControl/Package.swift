// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPluginControl",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderPluginControl", targets: ["ProviderPluginControl"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "ProviderPluginControl",
            dependencies: [.product(name: "KernelCore", package: "LumiKernel")],
            path: "Sources/ProviderPluginControl"
        ),
        .testTarget(
            name: "ProviderPluginControlTests",
            dependencies: [
                "ProviderPluginControl",
                .product(name: "KernelCore", package: "LumiKernel"),
            ]
        ),
    ]
)
