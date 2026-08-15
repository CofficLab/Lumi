// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FactoryBookletMaker",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FactoryBookletMaker", targets: ["FactoryBookletMaker"]),
    ],
    dependencies: [
        .package(path: "../FactoryCore"),
        .package(path: "../../Plugins/StoragePlugin"),
        .package(path: "../../Plugins/ProjectsPlugin"),
        .package(path: "../../Plugins/WorkspacePlugin"),
        .package(path: "../../Plugins/CommandPlugin"),
        .package(path: "../../Plugins/MessageSenderPlugin"),
        .package(path: "../../Plugins/LLMProviderManagerPlugin"),
        .package(path: "../../Plugins/AgentTurnRunnerPlugin"),
        .package(path: "../../Plugins/EditorHostPlugin"),
        .package(path: "../../Plugins/ToolManagerPlugin"),
        .package(path: "../../Plugins/SettingsPlugin"),
        .package(path: "../../Plugins/LogoPlugin"),
        .package(path: "../../Plugins/ThemeManagerPlugin"),
        .package(path: "../../Plugins/ThemeLumiPlugin"),
        .package(path: "../../Plugins/MessageRendererPlugin"),
        .package(path: "../../Plugins/BookletMakerPlugin"),
    ],
    targets: [
        .target(
            name: "FactoryBookletMaker",
            dependencies: [
                .product(name: "FactoryCore", package: "FactoryCore"),
                .product(name: "StoragePlugin", package: "StoragePlugin"),
                .product(name: "ProjectsPlugin", package: "ProjectsPlugin"),
                .product(name: "WorkspacePlugin", package: "WorkspacePlugin"),
                .product(name: "CommandPlugin", package: "CommandPlugin"),
                .product(name: "MessageSenderPlugin", package: "MessageSenderPlugin"),
                .product(name: "LLMProviderManagerPlugin", package: "LLMProviderManagerPlugin"),
                .product(name: "AgentTurnRunnerPlugin", package: "AgentTurnRunnerPlugin"),
                .product(name: "EditorHostPlugin", package: "EditorHostPlugin"),
                .product(name: "ToolManagerPlugin", package: "ToolManagerPlugin"),
                .product(name: "SettingsPlugin", package: "SettingsPlugin"),
                .product(name: "LogoPlugin", package: "LogoPlugin"),
                .product(name: "ThemeManagerPlugin", package: "ThemeManagerPlugin"),
                .product(name: "ThemeLumiPlugin", package: "ThemeLumiPlugin"),
                .product(name: "MessageRendererPlugin", package: "MessageRendererPlugin"),
                .product(name: "BookletMakerPlugin", package: "BookletMakerPlugin"),
            ]
        ),
        .testTarget(
            name: "FactoryBookletMakerTests",
            dependencies: ["FactoryBookletMaker"]
        ),
    ]
)
