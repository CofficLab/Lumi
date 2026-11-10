// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitKeychain",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitKeychain",
            targets: ["KitKeychain"]
        ),
    ],
    targets: [
        .target(
            name: "KitKeychain",
            dependencies: [],
            path: "Sources/KitKeychain"
        ),
        .testTarget(
            name: "KitKeychainTests",
            dependencies: ["KitKeychain"],
            path: "Tests/KitKeychainTests"
        )
    ]
)
