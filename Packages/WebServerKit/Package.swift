// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WebServerKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WebServerKit", targets: ["WebServerKit"])
    ],
    dependencies: [
        .package(name: "ProviderWebServer", path: "../ProviderWebServer"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "WebServerKit",
            dependencies: [
                .product(name: "ProviderWebServer", package: "ProviderWebServer"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            path: "Sources/WebServerKit"
        ),
        .testTarget(
            name: "WebServerKitTests",
            dependencies: ["WebServerKit"],
            path: "Tests/WebServerKitTests"
        )
    ]
)
