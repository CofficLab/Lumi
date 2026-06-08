// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiChatKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiChatKit",
            targets: ["LumiChatKit"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit")
    ],
    targets: [
        .target(
            name: "LumiChatKit",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "LumiChatKitTests",
            dependencies: ["LumiChatKit"],
            path: "Tests"
        )
    ]
)
