// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitLumiCLI",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
    ],
    products: [
        .library(
            name: "KitLumiCLI",
            targets: ["KitLumiCLI"]
        ),
    ],
    targets: [
        .target(
            name: "KitLumiCLI",
            path: "Sources/KitLumiCLI"
        ),
        .testTarget(
            name: "KitLumiCLITests",
            dependencies: ["KitLumiCLI"],
            path: "Tests/KitLumiCLITests"
        ),
    ]
)
