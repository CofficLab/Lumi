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
        .package(path: "../LumiUI"),
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
