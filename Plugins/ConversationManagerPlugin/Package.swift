// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationManagerPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ConversationManagerPlugin", targets: ["ConversationManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ConversationManagerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)
