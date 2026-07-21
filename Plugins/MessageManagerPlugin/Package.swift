// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageManagerPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageManagerPlugin", targets: ["MessageManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
    ],
    targets: [
        .target(
            name: "MessageManagerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Sources"
        ),
    ]
)
