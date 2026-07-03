// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OnboardingPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OnboardingPlugin",
            targets: ["OnboardingPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "OnboardingPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "OnboardingPluginTests",
            dependencies: ["OnboardingPlugin", .product(name: "LumiCoreKit", package: "LumiCoreKit")],
            path: "Tests"
        )
    ]
)
