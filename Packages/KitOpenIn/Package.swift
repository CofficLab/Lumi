// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitOpenIn",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "KitOpenIn", targets: ["KitOpenIn"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.22.0"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.0"),
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
