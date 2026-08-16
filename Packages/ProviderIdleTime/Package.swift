// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderIdleTime",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderIdleTime", targets: ["ProviderIdleTime"]),
    ],
    targets: [
        .target(name: "ProviderIdleTime", path: "Sources/ProviderIdleTime"),
    ]
)
