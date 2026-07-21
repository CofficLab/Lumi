// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageListPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageListPlugin", targets: ["MessageListPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "MessageListPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources"
        ),
    ]
)
