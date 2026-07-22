// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreChat",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreChat", targets: ["LumiCoreChat"])
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
    ],
    targets: [
        .target(
            name: "LumiCoreChat",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Sources"
        )
    ]
)
