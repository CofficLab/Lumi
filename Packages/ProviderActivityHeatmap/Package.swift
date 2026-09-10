// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderActivityHeatmap",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderActivityHeatmap", targets: ["ProviderActivityHeatmap"]),
    ],
    targets: [
        .target(
            name: "ProviderActivityHeatmap",
            path: "Sources/ProviderActivityHeatmap"
        ),
        .testTarget(
            name: "ProviderActivityHeatmapTests",
            dependencies: ["ProviderActivityHeatmap"],
            path: "Tests/ProviderActivityHeatmapTests"
        ),
    ]
)
