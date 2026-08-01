// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SubAgentProviderPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SubAgentProviderPlugin",
            targets: ["SubAgentProviderPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
    ],
    targets: [
        .target(
            name: "SubAgentProviderPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SubAgentProviderPluginTests",
            dependencies: ["SubAgentProviderPlugin"],
            path: "Tests"
        ),
    ]
)
