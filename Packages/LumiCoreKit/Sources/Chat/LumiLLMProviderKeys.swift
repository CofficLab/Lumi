import Foundation

public enum LumiLLMProviderKeys {
    public static let localProviderIDs: Set<String> = ["mlx", "codex"]

    public static func isLocalProvider(id: String) -> Bool {
        localProviderIDs.contains(id)
    }

    /// Returns the UserDefaults / Keychain storage key for a remote provider, if any.
    public static func apiKeyStorageKey(forProviderID id: String) -> String? {
        if isLocalProvider(id: id) {
            return nil
        }

        switch id {
        case "anthropic": return "DevAssistant_ApiKey_Anthropic"
        case "openai": return "DevAssistant_ApiKey_OpenAI"
        case "zhipu": return "DevAssistant_ApiKey_Zhipu"
        case "aliyun": return "DevAssistant_ApiKey_Aliyun"
        case "deepseek": return "DevAssistant_ApiKey_DeepSeek"
        case "openrouter": return "DevAssistant_ApiKey_OpenRouter"
        case "airouter": return "DevAssistant_ApiKey_AiRouter"
        case "feifeimiao": return "DevAssistant_ApiKey_Feifeimiao"
        case "flymux": return "DevAssistant_ApiKey_FlyMux"
        case "freemodel": return "DevAssistant_ApiKey_FreeModel"
        case "happycode": return "DevAssistant_ApiKey_HappyCode"
        case "hyperapi": return "DevAssistant_ApiKey_HyperAPI"
        case "lpgpt": return "DevAssistant_ApiKey_LPgpt"
        case "megallm": return "DevAssistant_ApiKey_MegaLLM"
        case "xiaomi": return "DevAssistant_ApiKey_Xiaomi"
        case "xiaomi-api": return "DevAssistant_ApiKey_XiaomiAPI"
        case "xybbz": return "DevAssistant_ApiKey_Xybbz"
        case "sublyx": return "DevAssistant_ApiKey_Sublyx"
        default: return "DevAssistant_ApiKey_\(id)"
        }
    }
}
