// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderWorkspace",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderWorkspace", targets: ["ProviderWorkspace"]),
    ],
    targets: [
        .target(name: "ProviderWorkspace", path: "Sources/ProviderWorkspace"),
        .testTarget(name: "ProviderWorkspaceTests", dependencies: ["ProviderWorkspace"]),
    ]
)
