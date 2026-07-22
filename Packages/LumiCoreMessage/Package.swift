// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreMessage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreMessage", targets: ["LumiCoreMessage"])
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
    ],
    targets: [
        .target(
            name: "LumiCoreMessage",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Sources"
        )
    ]
)
