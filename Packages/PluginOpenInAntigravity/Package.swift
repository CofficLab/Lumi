// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInAntigravity",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenInAntigravity", targets: ["PluginOpenInAntigravity"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
        .package(path: "../OpenInKit"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "PluginOpenInAntigravity",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "KitSuperLog",
                "OpenInKit",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderToolManager",
                "ProviderToolbar",
            ],
            path: "Sources/PluginOpenInAntigravity",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOpenInAntigravityTests",
            dependencies: [
                "PluginOpenInAntigravity",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "OpenInKit", package: "OpenInKit"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ]
        ),
    ]
)
