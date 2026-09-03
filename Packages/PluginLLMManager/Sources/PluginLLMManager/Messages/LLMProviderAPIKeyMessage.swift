import Foundation
import KitLLM
import ProviderMessage

/// API Key 相关错误消息的判定与渲染类型常量（KernelCore 生态）。
///
/// 复刻自旧版内核 KernelLumi 的 `LumiLLMProviderAPIKeyMessage`，
/// 消息类型从 `LumiChatMessage` 换成新体系 `Message`，判定规则保持一致；
/// renderKind 常量与供应商层（`LLMErrorRenderKind`）单一来源。
public enum LLMProviderAPIKeyMessage {
    /// 缺失渲染类型：`core-error-message`(order=300) 之上，优先接管。
    public static let missingRenderKind = LLMErrorRenderKind.apiKeyMissing
    /// Keychain 读取失败渲染类型。
    public static let accessFailedRenderKind = LLMErrorRenderKind.apiKeyAccessFailed
    /// 原始错误前缀（供应商/旧链路直接抛出的裸文本）。
    public static let rawErrorPrefix = "Missing API key for:"
    /// 旧 AgentLoop 使用 `String(describing:)` 后持久化的错误格式。
    public static let legacyErrorPrefix = "missingAPIKey(\""

    /// 是否属于「API Key 缺失」错误：显式 renderKind、后缀匹配或裸错误前缀。
    public static func isMissingAPIKeyMessage(_ message: Message) -> Bool {
        guard message.role == .error || message.isError else { return false }
        if message.renderKind == missingRenderKind {
            return true
        }
        if message.renderKind?.hasSuffix("api-key-missing") == true {
            return true
        }
        if message.rawErrorDetail?.hasPrefix(rawErrorPrefix) == true {
            return true
        }
        // 兼容修复前已经落库的 `missingAPIKey("Provider")` 消息。
        return message.content.hasPrefix(legacyErrorPrefix)
    }

    /// 是否属于「API Key 无法读取（Keychain 访问失败）」错误。
    public static func isAPIKeyAccessFailedMessage(_ message: Message) -> Bool {
        guard message.role == .error || message.isError else { return false }
        return message.renderKind == accessFailedRenderKind
    }
}
