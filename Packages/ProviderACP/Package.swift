// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderACP",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderACP", targets: ["ProviderACP"]),
    ],
    targets: [
        .target(
            name: "ProviderACP",
            path: "Sources/ProviderACP"
        ),
        .testTarget(
            name: "ProviderACPTests",
            dependencies: ["ProviderACP"],
            path: "Tests/ProviderACPTests"
        ),
    ]
)
