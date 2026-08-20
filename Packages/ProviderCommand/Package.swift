// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderCommand",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderCommand", targets: ["ProviderCommand"]),
    ],
    targets: [
        .target(name: "ProviderCommand", path: "Sources/ProviderCommand"),
        .testTarget(name: "ProviderCommandTests", dependencies: ["ProviderCommand"]),
    ]
)
