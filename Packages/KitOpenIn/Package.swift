// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitOpenIn",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "KitOpenIn", targets: ["KitOpenIn"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiUI"),
    ],
    targets: [
        .target(
            name: "KitOpenIn",
            dependencies: [
                "KitAgentTool",
                "LumiUI",
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
            ],
            path: "Sources/KitOpenIn",
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "KitOpenInTests",
            dependencies: [
                "KitOpenIn",
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
            ]
        ),
    ]
)
