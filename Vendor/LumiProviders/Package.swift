// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiProviders",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "ProviderActivityBar", targets: ["ProviderActivityBar"]),
        .library(name: "ProviderAppUpdate", targets: ["ProviderAppUpdate"]),
        .library(name: "ProviderAgentRules", targets: ["ProviderAgentRules"]),
        .library(name: "ProviderSkill", targets: ["ProviderSkill"]),
        .library(name: "ProviderConversationInput", targets: ["ProviderConversationInput"]),
        .library(name: "ProviderDeveloperMode", targets: ["ProviderDeveloperMode"]),
        .library(name: "ProviderOnboarding", targets: ["ProviderOnboarding"]),
        .library(name: "ProviderCommand", targets: ["ProviderCommand"]),
        .library(name: "ProviderContentView", targets: ["ProviderContentView"]),
        .library(name: "ProviderDocsView", targets: ["ProviderDocsView"]),
        .library(name: "ProviderMenuBar", targets: ["ProviderMenuBar"]),
        .library(name: "MenuBarHostKit", targets: ["MenuBarHostKit"]),
        .library(name: "ProviderNetwork", targets: ["ProviderNetwork"]),
        .library(name: "ProviderProject", targets: ["ProviderProject"]),
        .library(name: "ProviderIdleTime", targets: ["ProviderIdleTime"]),
        .library(name: "ProviderRailView", targets: ["ProviderRailView"]),
        .library(name: "ProviderStatusBar", targets: ["ProviderStatusBar"]),
        .library(name: "ProviderPluginControl", targets: ["ProviderPluginControl"]),
        .library(name: "ProviderPluginManaging", targets: ["ProviderPluginManaging"]),
        .library(name: "ProviderRootView", targets: ["ProviderRootView"]),
        .library(name: "ProviderStorage", targets: ["ProviderStorage"]),
        .library(name: "ProviderTheme", targets: ["ProviderTheme"]),
        .library(name: "ProviderToast", targets: ["ProviderToast"]),
        .library(name: "ProviderToolbar", targets: ["ProviderToolbar"]),
        .library(name: "PluginToolbar", targets: ["PluginToolbar"]),
        .library(name: "ProviderLogo", targets: ["ProviderLogo"]),
        .library(name: "ProviderUninstall", targets: ["ProviderUninstall"]),
        .library(name: "ProviderPromptSuggestion", targets: ["ProviderPromptSuggestion"]),
        .library(name: "ProviderStore", targets: ["ProviderStore"]),
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
        .package(path: "../LumiLogging"),
        .package(path: "../LumiLocalization"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "ProviderCommand",
            path: "Sources/ProviderCommand"
        ),
        .testTarget(
            name: "ProviderCommandTests",
            dependencies: ["ProviderCommand"],
            path: "Tests/ProviderCommandTests"
        ),
        .target(
            name: "ProviderPluginControl",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
            ],
            path: "Sources/ProviderPluginControl"
        ),
        .testTarget(
            name: "ProviderPluginControlTests",
            dependencies: [
                "ProviderPluginControl",
                .product(name: "KernelCore", package: "LumiKernel"),
            ],
            path: "Tests/ProviderPluginControlTests"
        ),
        .target(
            name: "ProviderPluginManaging",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderPluginControl",
            ],
            path: "Sources/ProviderPluginManaging"
        ),
        .testTarget(
            name: "ProviderPluginManagingTests",
            dependencies: [
                "ProviderPluginManaging",
                "ProviderPluginControl",
                .product(name: "KernelCore", package: "LumiKernel"),
            ],
            path: "Tests/ProviderPluginManagingTests"
        ),
        .target(
            name: "ProviderRootView",
            dependencies: ["ProviderRailView"],
            path: "Sources/ProviderRootView"
        ),
        .testTarget(
            name: "ProviderRootViewTests",
            dependencies: ["ProviderRootView"],
            path: "Tests/ProviderRootViewTests"
        ),
        .target(
            name: "ProviderContentView",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ProviderContentView",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ProviderContentViewTests",
            dependencies: ["ProviderContentView"],
            path: "Tests/ProviderContentViewTests"
        ),
        .target(
            name: "ProviderDocsView",
            path: "Sources/ProviderDocsView"
        ),
        .testTarget(
            name: "ProviderDocsViewTests",
            dependencies: ["ProviderDocsView"],
            path: "Tests/ProviderDocsViewTests"
        ),
        .target(
            name: "ProviderMenuBar",
            path: "Sources/ProviderMenuBar"
        ),
        .testTarget(
            name: "ProviderMenuBarTests",
            dependencies: [
                "ProviderMenuBar",
                .product(name: "KernelCore", package: "LumiKernel"),
            ],
            path: "Tests/ProviderMenuBarTests"
        ),
        .target(
            name: "MenuBarHostKit",
            path: "Sources/MenuBarHostKit"
        ),
        .testTarget(
            name: "MenuBarHostKitTests",
            dependencies: ["MenuBarHostKit"],
            path: "Tests/MenuBarHostKitTests"
        ),
        .target(
            name: "ProviderNetwork",
            path: "Sources/ProviderNetwork"
        ),
        .testTarget(
            name: "ProviderNetworkTests",
            dependencies: ["ProviderNetwork"],
            path: "Tests/ProviderNetworkTests"
        ),
        .target(
            name: "ProviderProject",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ProviderProject"
        ),
        .testTarget(
            name: "ProviderProjectTests",
            dependencies: ["ProviderProject"],
            path: "Tests/ProviderProjectTests"
        ),
        .target(
            name: "ProviderIdleTime",
            path: "Sources/ProviderIdleTime"
        ),
        .testTarget(
            name: "ProviderIdleTimeTests",
            dependencies: ["ProviderIdleTime"],
            path: "Tests/ProviderIdleTimeTests"
        ),
        .target(
            name: "ProviderRailView",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ProviderRailView"
        ),
        .testTarget(
            name: "ProviderRailViewTests",
            dependencies: ["ProviderRailView"],
            path: "Tests/ProviderRailViewTests"
        ),
        .target(
            name: "ProviderStatusBar",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ProviderStatusBar"
        ),
        .testTarget(
            name: "ProviderStatusBarTests",
            dependencies: ["ProviderStatusBar"],
            path: "Tests/ProviderStatusBarTests"
        ),
        .target(
            name: "ProviderStorage",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ProviderStorage"
        ),
        .testTarget(
            name: "ProviderStorageTests",
            dependencies: [
                "ProviderStorage",
                .product(name: "KernelCore", package: "LumiKernel"),
            ],
            path: "Tests/ProviderStorageTests"
        ),
        .target(
            name: "ProviderToast",
            path: "Sources/ProviderToast"
        ),
        .testTarget(
            name: "ProviderToastTests",
            dependencies: ["ProviderToast"],
            path: "Tests/ProviderToastTests"
        ),
        .target(
            name: "ProviderTheme",
            path: "Sources/ProviderTheme",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ProviderThemeTests",
            dependencies: ["ProviderTheme"],
            path: "Tests/ProviderThemeTests"
        ),
        .target(
            name: "ProviderToolbar",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ProviderToolbar"
        ),
        .testTarget(
            name: "ProviderToolbarTests",
            dependencies: ["ProviderToolbar", "PluginToolbar"],
            path: "Tests/ProviderToolbarTests"
        ),
        .target(
            name: "PluginToolbar",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderPluginManaging",
                "ProviderToolbar",
            ],
            path: "Sources/PluginToolbar"
        ),
        .testTarget(
            name: "PluginToolbarTests",
            dependencies: [
                "PluginToolbar",
                "ProviderPluginManaging",
                "ProviderToolbar",
                .product(name: "KernelCore", package: "LumiKernel"),
            ],
            path: "Tests/PluginToolbarTests"
        ),
        .target(
            name: "ProviderLogo",
            path: "Sources/ProviderLogo"
        ),
        .testTarget(
            name: "ProviderLogoTests",
            dependencies: ["ProviderLogo"],
            path: "Tests/ProviderLogoTests"
        ),
        .target(
            name: "ProviderActivityBar",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ProviderActivityBar"
        ),
        .testTarget(
            name: "ProviderActivityBarTests",
            dependencies: ["ProviderActivityBar"],
            path: "Tests/ProviderActivityBarTests"
        ),
        .target(
            name: "ProviderAppUpdate",
            path: "Sources/ProviderAppUpdate"
        ),
        .testTarget(
            name: "ProviderAppUpdateTests",
            dependencies: ["ProviderAppUpdate"],
            path: "Tests/ProviderAppUpdateTests"
        ),
        .target(
            name: "ProviderAgentRules",
            path: "Sources/ProviderAgentRules"
        ),
        .testTarget(
            name: "ProviderAgentRulesTests",
            dependencies: ["ProviderAgentRules"],
            path: "Tests/ProviderAgentRulesTests"
        ),
        .target(
            name: "ProviderSkill",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ProviderSkill"
        ),
        .testTarget(
            name: "ProviderSkillTests",
            dependencies: ["ProviderSkill"],
            path: "Tests/ProviderSkillTests"
        ),
        .target(
            name: "ProviderConversationInput",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ProviderConversationInput"
        ),
        .testTarget(
            name: "ProviderConversationInputTests",
            dependencies: ["ProviderConversationInput"],
            path: "Tests/ProviderConversationInputTests"
        ),
        .target(
            name: "ProviderDeveloperMode",
            path: "Sources/ProviderDeveloperMode"
        ),
        .testTarget(
            name: "ProviderDeveloperModeTests",
            dependencies: ["ProviderDeveloperMode"],
            path: "Tests/ProviderDeveloperModeTests"
        ),
        .target(
            name: "ProviderOnboarding",
            path: "Sources/ProviderOnboarding"
        ),
        .testTarget(
            name: "ProviderOnboardingTests",
            dependencies: ["ProviderOnboarding"],
            path: "Tests/ProviderOnboardingTests"
        ),
        .target(
            name: "ProviderUninstall",
            path: "Sources/ProviderUninstall"
        ),
        .testTarget(
            name: "ProviderUninstallTests",
            dependencies: ["ProviderUninstall"],
            path: "Tests/ProviderUninstallTests"
        ),
        .target(
            name: "ProviderPromptSuggestion",
            path: "Sources/ProviderPromptSuggestion"
        ),
        .testTarget(
            name: "ProviderPromptSuggestionTests",
            dependencies: ["ProviderPromptSuggestion"],
            path: "Tests/ProviderPromptSuggestionTests"
        ),
        .target(
            name: "ProviderStore",
            path: "Sources/ProviderStore"
        ),
        .testTarget(
            name: "ProviderStoreTests",
            dependencies: ["ProviderStore"],
            path: "Tests/ProviderStoreTests"
        ),
    ]
)
