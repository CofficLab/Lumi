// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiLocalization",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17),
    ],
    products: [
        .library(name: "LumiLocalizationKit", targets: ["LumiLocalizationKit"]),
    ],
    targets: [
        .target(name: "LumiLocalizationKit"),
        .testTarget(
            name: "LumiLocalizationKitTests",
            dependencies: ["LumiLocalizationKit"]
        ),
    ]
)
