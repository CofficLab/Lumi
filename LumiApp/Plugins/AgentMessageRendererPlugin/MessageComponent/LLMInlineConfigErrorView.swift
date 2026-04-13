import MagicKit
import SwiftUI

/// LLM 配置错误视图
///
/// `LLMServiceError` 转为错误消息后的专用说明（占位键由 `ChatMessage` 定义）。
struct LLMInlineConfigErrorView: View {
    @EnvironmentObject private var projectVM: ProjectVM

    let message: ChatMessage

    private var zh: Bool {
        projectVM.languagePreference == .chinese
    }

    private var titleText: String {
        let c = message.content
        if c == ChatMessage.llmModelEmptyContentKey {
            return zh ? "模型未填写" : "Model is empty"
        }
        if c == ChatMessage.llmProviderIdEmptyContentKey {
            return zh ? "供应商未选择" : "Provider is not set"
        }
        if c == ChatMessage.llmTemperatureInvalidContentKey {
            return zh ? "温度参数无效" : "Invalid temperature"
        }
        if c == ChatMessage.llmMaxTokensInvalidContentKey {
            return zh ? "最大 token 无效" : "Invalid max tokens"
        }
        if c == ChatMessage.llmProviderNotFoundContentKey {
            return zh ? "找不到供应商" : "Provider not found"
        }
        if c.hasPrefix(ChatMessage.llmInvalidBaseURLContentKey) {
            return zh ? "Base URL 无效" : "Invalid Base URL"
        }
        return zh ? "配置错误" : "Configuration error"
    }

    private var detailText: String {
        let c = message.content
        if c == ChatMessage.llmTemperatureInvalidContentKey, let t = message.temperature {
            return zh
                ? "温度应在 0～2 之间，当前为 \(t)。"
                : "Temperature must be between 0 and 2; current value is \(t)."
        }
        if c == ChatMessage.llmMaxTokensInvalidContentKey, let m = message.maxTokens {
            return zh
                ? "最大 token 数应大于 0，当前为 \(m)。"
                : "Max tokens must be greater than 0; current value is \(m)."
        }
        if c == ChatMessage.llmProviderNotFoundContentKey, let id = message.providerId, !id.isEmpty {
            return zh
                ? "注册表中没有 ID 为「\(id)」的供应商实现。"
                : "No provider implementation registered for id \"\(id)\"."
        }
        if c.hasPrefix(ChatMessage.llmInvalidBaseURLContentKey) {
            if let raw = ChatMessage.llmInvalidBaseURLPayload(fromContent: c), !raw.isEmpty {
                return zh ? "无法解析为有效 URL：\(raw)" : "Cannot parse as a valid URL: \(raw)"
            }
            return zh ? "供应商返回的 Base URL 无法解析。" : "The provider's Base URL cannot be parsed."
        }
        if c == ChatMessage.llmModelEmptyContentKey {
            return zh ? "请选择或填写模型名称后再发送。" : "Choose or enter a model name before sending."
        }
        if c == ChatMessage.llmProviderIdEmptyContentKey {
            return zh ? "请选择 LLM 供应商。" : "Select an LLM provider."
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ErrorIconView(size: 14)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(AppUI.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                    if !detailText.isEmpty {
                        Text(detailText)
                            .font(AppUI.Typography.caption1)
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}
