// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationManagerPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ConversationManagerPlugin", targets: ["ConversationManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "ConversationManagerPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ConversationManagerPluginTests",
            dependencies: [
                "ConversationManagerPlugin",
                .product(name: "KernelLumi", package: "KernelLumi"),
            ],
            path: "Tests"
        ),
    ]
)
