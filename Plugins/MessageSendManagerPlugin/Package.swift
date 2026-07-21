// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageSendManagerPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageSendManagerPlugin", targets: ["MessageSendManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiCoreMessage"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "MessageSendManagerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)
