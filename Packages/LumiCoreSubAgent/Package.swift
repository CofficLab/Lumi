// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreSubAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreSubAgent", targets: ["LumiCoreSubAgent"])
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
    ],
    targets: [
        .target(
            name: "LumiCoreSubAgent",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Sources"
        )
    ]
)
