// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderSkill",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderSkill",
            targets: ["ProviderSkill"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "ProviderSkill",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ProviderSkill"
        ),
        .testTarget(
            name: "ProviderSkillTests",
            dependencies: ["ProviderSkill"]
        )
    ]
)