// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeychainKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "KeychainKit",
            targets: ["KeychainKit"]
        ),
    ],
    targets: [
        .target(
            name: "KeychainKit",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "KeychainKitTests",
            dependencies: ["KeychainKit"],
            path: "Tests/KeychainKitTests"
        )
    ]
)
