// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderProject",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderProject",
            targets: ["ProviderProject"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "ProviderProject",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ProviderProject"
        ),
        .testTarget(
            name: "ProviderProjectTests",
            dependencies: ["ProviderProject"]
        )
    ]
)
