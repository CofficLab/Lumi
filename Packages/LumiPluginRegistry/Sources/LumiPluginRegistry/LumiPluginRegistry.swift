import LumiCoreKit
import DeviceInfoPlugin
import NetworkManagerPlugin
import ChatPanelPlugin
import LLMProviderOpenAIPlugin
import LLMProviderZhipuPlugin
import LLMProviderAiRouterPlugin
import LLMProviderAliyunPlugin
import LLMProviderAnthropicPlugin
import LLMProviderDeepSeekPlugin
import LLMProviderFeifeimiaoPlugin
import LLMProviderFlyMuxPlugin
import LLMProviderFreeModelPlugin
import LLMProviderHappyCodePlugin
import LLMProviderHyperAPIPlugin
import LLMProviderLPgptPlugin
import LLMProviderMegaLLMPlugin
import LLMProviderOpenRouterPlugin
import LLMProviderXiaomiPlugin
import LLMProviderXybbzPlugin
import LLMProviderCodexPlugin
import LLMProviderMLXPlugin
import ChatMiddlewarePlugin
import ProjectsPlugin
import AppManagerPlugin
import DiskManagerPlugin
import PortManagerPlugin
import ToolCorePlugin
import MessageRendererPlugin
import ThemeLumiPlugin
import ThemeMidnightPlugin
import ThemeSkyPlugin
import ThemeAuroraPlugin
import ThemeNebulaPlugin
import ThemeVoidPlugin
import ThemeSpringPlugin
import ThemeSummerPlugin
import ThemeAutumnPlugin
import ThemeWinterPlugin
import ThemeGithubPlugin
import ThemeOrchardPlugin
import ThemeMountainPlugin
import ThemeVscodeDarkPlugin
import ThemeRiverPlugin
import ThemeVscodeLightPlugin
import ThemeOneDarkPlugin
import ThemeDraculaPlugin
import ThemeStatusBarPlugin

@MainActor
public enum LumiPluginRegistry {
    public static let plugins: [any LumiPlugin.Type] = [
        ThemeLumiPlugin.self,
        ThemeMidnightPlugin.self,
        ThemeSkyPlugin.self,
        ThemeAuroraPlugin.self,
        ThemeNebulaPlugin.self,
        ThemeVoidPlugin.self,
        ThemeSpringPlugin.self,
        ThemeSummerPlugin.self,
        ThemeAutumnPlugin.self,
        ThemeWinterPlugin.self,
        ThemeGithubPlugin.self,
        ThemeOrchardPlugin.self,
        ThemeMountainPlugin.self,
        ThemeVscodeDarkPlugin.self,
        ThemeRiverPlugin.self,
        ThemeVscodeLightPlugin.self,
        ThemeOneDarkPlugin.self,
        ThemeDraculaPlugin.self,
        ThemeStatusBarPlugin.self,
        DeviceInfoPlugin.self,
        NetworkManagerPlugin.self,
        ChatPanelPlugin.self,
        OpenAIPlugin.self,
        ZhipuPlugin.self,
        AiRouterPlugin.self,
        AliyunPlugin.self,
        AnthropicPlugin.self,
        DeepSeekPlugin.self,
        FeifeimiaoPlugin.self,
        FlyMuxPlugin.self,
        FreeModelPlugin.self,
        HappyCodePlugin.self,
        HyperAPIPlugin.self,
        LPgptPlugin.self,
        MegaLLMPlugin.self,
        OpenRouterPlugin.self,
        XiaomiPlugin.self,
        XybbzPlugin.self,
        CodexLumiPlugin.self,
        MLXLumiPlugin.self,
        AppManagerPlugin.self,
        DiskManagerPlugin.self,
        PortManagerPlugin.self,
        ToolCorePlugin.self,
        MessageRendererPlugin.self,
        ChatMiddlewarePlugin.self,
        ProjectsPlugin.self
    ]
}
