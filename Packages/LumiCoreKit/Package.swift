// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiCoreKit",
            targets: ["LumiCoreKit"]
        )
    ],
    targets: [
        .target(
            name: "LumiCoreKit",
            path: "Sources"
        ),
        .testTarget(
            name: "LumiCoreKitTests",
            dependencies: ["LumiCoreKit"]
        )
    ]
)
