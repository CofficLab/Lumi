// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPanelBottom",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderPanelBottom",
            targets: ["ProviderPanelBottom"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ProviderPanelBottom",
            dependencies: [],
            path: "Sources/ProviderPanelBottom"
        ),
        .testTarget(
            name: "ProviderPanelBottomTests",
            dependencies: ["ProviderPanelBottom"],
            path: "Tests/ProviderPanelBottomTests"
        )
    ]
)
