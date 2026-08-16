// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLegacyData",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderLegacyData", targets: ["ProviderLegacyData"]),
    ],
    targets: [
        .target(name: "ProviderLegacyData", path: "Sources/ProviderLegacyData"),
    ]
)
