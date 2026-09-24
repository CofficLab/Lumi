// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPluginControl",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderPluginControl", targets: ["ProviderPluginControl"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
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
