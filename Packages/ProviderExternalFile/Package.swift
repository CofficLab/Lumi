// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderExternalFile",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ProviderExternalFile", targets: ["ProviderExternalFile"])],
    targets: [
        .target(name: "ProviderExternalFile"),
        .testTarget(name: "ProviderExternalFileTests", dependencies: ["ProviderExternalFile"]),
    ]
)
