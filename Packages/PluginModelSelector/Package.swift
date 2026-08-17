// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginModelSelector",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginModelSelector", targets: ["PluginModelSelector"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLMVendors"),
    ],
    targets: [
        .target(
            name: "PluginModelSelector",
            dependencies: [
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderChatSection",
                "ProviderLLMManager",
                "ProviderLLMVendors",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginModelSelectorTests",
            dependencies: ["PluginModelSelector"]
        ),
    ]
)
