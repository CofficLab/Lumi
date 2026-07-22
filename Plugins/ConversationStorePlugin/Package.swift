// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationStorePlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ConversationStorePlugin", targets: ["ConversationStorePlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiCoreMessage"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ConversationStorePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)
