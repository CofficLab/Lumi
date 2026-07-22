// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageSenderPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageSenderPlugin", targets: ["MessageSenderPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiCoreMessage"),
        .package(path: "../../Packages/LumiCoreLLMProvider"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "MessageSenderPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)
