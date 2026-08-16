// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginHostsManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginHostsManager", targets: ["PluginHostsManager"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginHostsManager",
            dependencies: [
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderDocsView",
                "SuperLogKit",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginHostsManagerTests",
            dependencies: [
                "PluginHostsManager",
            ]
        ),
    ]
)
