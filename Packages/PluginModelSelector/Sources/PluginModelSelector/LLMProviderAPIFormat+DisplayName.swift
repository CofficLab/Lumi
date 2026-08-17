import Foundation
import ProviderLLMManager
import ProviderLLMVendors
/// API 协议格式的面向用户展示名（对应旧版 `LumiLLMAPIFormat.displayName`）。
extension LLMProviderAPIFormat {
    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .responses: "Responses"
        }
    }
}
