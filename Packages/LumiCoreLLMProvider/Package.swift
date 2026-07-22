// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreLLMProvider",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreLLMProvider", targets: ["LumiCoreLLMProvider"])
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
    ],
    targets: [
        .target(
            name: "LumiCoreLLMProvider",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Sources"
        )
    ]
)
