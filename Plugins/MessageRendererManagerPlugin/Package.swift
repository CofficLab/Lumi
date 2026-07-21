// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageRendererManagerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "MessageRendererManagerPlugin",
            targets: ["MessageRendererManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiCoreMessage"),
    ],
    targets: [
        .target(
            name: "MessageRendererManagerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
            ],
            path: "Sources/MessageRendererManagerPlugin"
        )
    ]
)
