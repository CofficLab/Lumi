// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentTempStoragePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentTempStoragePlugin",
            targets: ["AgentTempStoragePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "AgentTempStoragePlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        )
    ]
)
