// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginHydrationReminder",
    defaultLocalization: "en",
    platforms: [.macOS("13.1")],
    products: [
        .library(
            name: "PluginHydrationReminder",
            targets: ["PluginHydrationReminder"]
        )
    ],
    dependencies: [
        .package(path: "../LumiKitReminder"),
        .package(path: "../LumiLogging"),
        .package(path: "../LumiKernel"),
        .package(path: "../LumiSettings"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiProviders")
    ],
    targets: [
        .target(
            name: "PluginHydrationReminder",
            dependencies: [
                .product(name: "KitReminder", package: "LumiKitReminder"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders")
            ],
            path: "Sources/PluginHydrationReminder",
            resources: [.process("../../Resources/HydrationReminder.xcstrings")]
        ),
        .testTarget(
            name: "PluginHydrationReminderTests",
            dependencies: [
                "PluginHydrationReminder",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderMenuBar", package: "LumiProviders")
            ],
            path: "Tests/PluginHydrationReminderTests"
        )
    ]
)
