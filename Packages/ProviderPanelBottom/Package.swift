// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPanelBottom",
    platforms: [
        .macOS("13.1"),
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
