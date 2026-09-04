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
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "ProviderSkill",
            dependencies: [
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/ProviderSkill"
        ),
        .testTarget(
            name: "ProviderSkillTests",
            dependencies: ["ProviderSkill"]
        )
    ]
)