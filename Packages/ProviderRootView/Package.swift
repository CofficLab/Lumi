// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderRootView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderRootView",
            targets: ["ProviderRootView"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
        .package(path: "../ProviderWorkspace"),
    ],
    targets: [
        .target(
            name: "ProviderRootView",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
            ],
            path: "Sources/ProviderRootView"
        ),
        .testTarget(
            name: "ProviderRootViewTests",
            dependencies: [
                "ProviderRootView",
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
            ]
        )
    ]
)
