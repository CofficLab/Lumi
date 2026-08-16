// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginResumeDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginResumeDesigner", targets: ["PluginResumeDesigner"]),
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../HTMLPreviewKit"),
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ResumeKit"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRuntime"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginResumeDesigner",
            dependencies: [
                "AgentToolKit",
                "HTMLPreviewKit",
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ResumeKit",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderRailView",
                "ProviderStorage",
                "ProviderToolManager",
                .product(name: "ProviderConversationInput", package: "ProviderRuntime"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginResumeDesignerTests",
            dependencies: [
                "PluginResumeDesigner",
                "AgentToolKit",
                "KernelCore",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderRailView",
                "ProviderStorage",
                "ProviderToolManager",
            ]
        ),
    ]
)
