// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitWebServer",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "KitWebServer", targets: ["KitWebServer"])
    ],
    dependencies: [
        .package(name: "ProviderWebServer", path: "../ProviderWebServer"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "KitWebServer",
            dependencies: [
                .product(name: "ProviderWebServer", package: "ProviderWebServer"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            path: "Sources/KitWebServer"
        ),
        .testTarget(
            name: "KitWebServerTests",
            dependencies: ["KitWebServer"],
            path: "Tests/KitWebServerTests"
        )
    ]
)
