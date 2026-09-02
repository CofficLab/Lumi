// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderActivityBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderActivityBar",
            targets: ["ProviderActivityBar"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "ProviderActivityBar",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ProviderActivityBar"
        ),
        .testTarget(
            name: "ProviderActivityBarTests",
            dependencies: ["ProviderActivityBar"]
        )
    ]
)
