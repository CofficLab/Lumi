// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginRegistry",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiPluginRegistry",
            targets: ["LumiPluginRegistry"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../../Plugins/ThemeLumiPlugin"),
        .package(path: "../../Plugins/ThemeMidnightPlugin"),
        .package(path: "../../Plugins/ThemeSkyPlugin"),
        .package(path: "../../Plugins/ThemeAuroraPlugin"),
        .package(path: "../../Plugins/ThemeNebulaPlugin"),
        .package(path: "../../Plugins/ThemeVoidPlugin"),
        .package(path: "../../Plugins/ThemeSpringPlugin"),
        .package(path: "../../Plugins/ThemeSummerPlugin"),
        .package(path: "../../Plugins/ThemeAutumnPlugin"),
        .package(path: "../../Plugins/ThemeWinterPlugin"),
        .package(path: "../../Plugins/ThemeGithubPlugin"),
        .package(path: "../../Plugins/ThemeOrchardPlugin"),
        .package(path: "../../Plugins/ThemeMountainPlugin"),
        .package(path: "../../Plugins/ThemeVscodeDarkPlugin"),
        .package(path: "../../Plugins/ThemeRiverPlugin"),
        .package(path: "../../Plugins/ThemeVscodeLightPlugin"),
        .package(path: "../../Plugins/ThemeOneDarkPlugin"),
        .package(path: "../../Plugins/ThemeDraculaPlugin"),
        .package(path: "../../Plugins/ThemeStatusBarPlugin"),
        .package(path: "../../Plugins/DeviceInfoPlugin"),
        .package(path: "../../Plugins/NetworkManagerPlugin"),
        .package(path: "../../Plugins/ChatPanelPlugin"),
        .package(path: "../../Plugins/LLMProviderOpenAIPlugin"),
        .package(path: "../../Plugins/LLMProviderZhipuPlugin"),
        .package(path: "../../Plugins/ProjectsPlugin"),
        .package(path: "../../Plugins/AppManagerPlugin"),
        .package(path: "../../Plugins/DiskManagerPlugin"),
        .package(path: "../../Plugins/PortManagerPlugin"),
        .package(path: "../../Plugins/ToolCorePlugin"),
        .package(path: "../../Plugins/MessageRendererPlugin")
    ],
    targets: [
        .target(
            name: "LumiPluginRegistry",
            dependencies: [
                "LumiCoreKit",
                .product(name: "ThemeLumiPlugin", package: "ThemeLumiPlugin"),
                .product(name: "ThemeMidnightPlugin", package: "ThemeMidnightPlugin"),
                .product(name: "ThemeSkyPlugin", package: "ThemeSkyPlugin"),
                .product(name: "ThemeAuroraPlugin", package: "ThemeAuroraPlugin"),
                .product(name: "ThemeNebulaPlugin", package: "ThemeNebulaPlugin"),
                .product(name: "ThemeVoidPlugin", package: "ThemeVoidPlugin"),
                .product(name: "ThemeSpringPlugin", package: "ThemeSpringPlugin"),
                .product(name: "ThemeSummerPlugin", package: "ThemeSummerPlugin"),
                .product(name: "ThemeAutumnPlugin", package: "ThemeAutumnPlugin"),
                .product(name: "ThemeWinterPlugin", package: "ThemeWinterPlugin"),
                .product(name: "ThemeGithubPlugin", package: "ThemeGithubPlugin"),
                .product(name: "ThemeOrchardPlugin", package: "ThemeOrchardPlugin"),
                .product(name: "ThemeMountainPlugin", package: "ThemeMountainPlugin"),
                .product(name: "ThemeVscodeDarkPlugin", package: "ThemeVscodeDarkPlugin"),
                .product(name: "ThemeRiverPlugin", package: "ThemeRiverPlugin"),
                .product(name: "ThemeVscodeLightPlugin", package: "ThemeVscodeLightPlugin"),
                .product(name: "ThemeOneDarkPlugin", package: "ThemeOneDarkPlugin"),
                .product(name: "ThemeDraculaPlugin", package: "ThemeDraculaPlugin"),
                .product(name: "ThemeStatusBarPlugin", package: "ThemeStatusBarPlugin"),
                .product(name: "DeviceInfoPlugin", package: "DeviceInfoPlugin"),
                .product(name: "NetworkManagerPlugin", package: "NetworkManagerPlugin"),
                .product(name: "ChatPanelPlugin", package: "ChatPanelPlugin"),
                .product(name: "LLMProviderOpenAIPlugin", package: "LLMProviderOpenAIPlugin"),
                .product(name: "LLMProviderZhipuPlugin", package: "LLMProviderZhipuPlugin"),
                "ProjectsPlugin",
                .product(name: "AppManagerPlugin", package: "AppManagerPlugin"),
                .product(name: "DiskManagerPlugin", package: "DiskManagerPlugin"),
                .product(name: "PortManagerPlugin", package: "PortManagerPlugin"),
                .product(name: "ToolCorePlugin", package: "ToolCorePlugin"),
                .product(name: "MessageRendererPlugin", package: "MessageRendererPlugin")
            ]
        )
    ]
)
