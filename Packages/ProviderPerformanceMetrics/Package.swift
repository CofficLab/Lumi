// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPerformanceMetrics",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProviderPerformanceMetrics", targets: ["ProviderPerformanceMetrics"]),
    ],
    targets: [
        .target(name: "ProviderPerformanceMetrics"),
        .testTarget(
            name: "ProviderPerformanceMetricsTests",
            dependencies: ["ProviderPerformanceMetrics"]
        ),
    ]
)
