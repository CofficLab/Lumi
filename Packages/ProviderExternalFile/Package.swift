// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderExternalFile",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [.library(name: "ProviderExternalFile", targets: ["ProviderExternalFile"])],
    targets: [
        .target(name: "ProviderExternalFile"),
        .testTarget(name: "ProviderExternalFileTests", dependencies: ["ProviderExternalFile"]),
    ]
)
