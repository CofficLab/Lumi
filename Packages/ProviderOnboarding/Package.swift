// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderOnboarding",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderOnboarding", targets: ["ProviderOnboarding"]),
    ],
    targets: [
        .target(name: "ProviderOnboarding", path: "Sources/ProviderOnboarding"),
    ]
)
