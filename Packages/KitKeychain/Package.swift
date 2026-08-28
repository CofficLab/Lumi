// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitKeychain",
    platforms: [
        .macOS(.v14),
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
            path: "Sources"
        ),
        .testTarget(
            name: "KitKeychainTests",
            dependencies: ["KitKeychain"],
            path: "Tests/KitKeychainTests"
        )
    ]
)
