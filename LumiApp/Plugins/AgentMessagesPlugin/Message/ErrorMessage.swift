import MagicKit
import SwiftUI

// MARK: - Error Message
//
/// 负责渲染错误类消息（如 API 调用失败、网络错误等），统一样式
struct ErrorMessage: View {
    let message: ChatMessage
    @Binding var showRawMessage: Bool

    @EnvironmentObject private var projectVM: ProjectVM

    private var zh: Bool {
        projectVM.languagePreference == .chinese
    }

    private var titleText: String {
        zh ? "错误" : "Error"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            VStack(alignment: .leading, spacing: 8) {
                if message.content == ChatMessage.apiKeyMissingSystemContentKey {
                    // API Key 缺失特殊处理：提供可交互的输入视图
                    ApiKeyMissingErrorView(message: message)
                } else if isSpecialError {
                    specialErrorView
                } else if isLLMConfigError {
                    llmConfigErrorView
                } else {
                    defaultErrorView
                }
            }
            .messageBubbleStyle(role: message.role, isError: true)
        }
    }

    // MARK: - Special Error Detection

    /// 是否为特殊错误消息（使用占位键的错误）
    private var isSpecialError: Bool {
        let c = message.content
        return c == ChatMessage.apiRequestFailedErrorKey ||
               c == ChatMessage.networkConnectionErrorKey ||
               c == ChatMessage.parsingErrorKey ||
               c == ChatMessage.authenticationErrorKey ||
               c == ChatMessage.quotaExceededErrorKey ||
               c == ChatMessage.modelNotAvailableErrorKey ||
               c == ChatMessage.loadingLocalModelFailedSystemContentKey
    }

    /// 是否为 LLM 配置错误消息（排除 API Key 缺失，因为已经单独处理）
    private var isLLMConfigError: Bool {
        let c = message.content
        return c == ChatMessage.llmModelEmptyContentKey ||
               c == ChatMessage.llmProviderIdEmptyContentKey ||
               c == ChatMessage.llmTemperatureInvalidContentKey ||
               c == ChatMessage.llmMaxTokensInvalidContentKey ||
               c == ChatMessage.llmProviderNotFoundContentKey ||
               c.hasPrefix(ChatMessage.llmInvalidBaseURLContentKey)
    }

    // MARK: - Special Error Views

    @ViewBuilder
    private var specialErrorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                errorIcon
                errorContent
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var llmConfigErrorView: some View {
        LLMInlineConfigErrorView(message: message)
    }

    @ViewBuilder
    private var defaultErrorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                errorIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(AppUI.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)

                    if !message.content.isEmpty {
                        PlainTextMessageContentView(
                            content: message.content,
                            monospaced: false
                        )
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Error Icon

    private var errorIcon: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(AppUI.Color.semantic.error)
    }

    // MARK: - Error Content

    @ViewBuilder
    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(errorTitle)
                .font(AppUI.Typography.callout)
                .fontWeight(.semibold)
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            if !errorDescription.isEmpty {
                Text(errorDescription)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 显示建议操作
            if !errorSuggestion.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.warning)
                    Text(errorSuggestion)
                        .font(AppUI.Typography.caption2)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Error Details

    private var errorTitle: String {
        let c = message.content
        switch c {
        case ChatMessage.apiRequestFailedErrorKey:
            return zh ? "API 请求失败" : "API Request Failed"
        case ChatMessage.networkConnectionErrorKey:
            return zh ? "网络连接失败" : "Network Connection Failed"
        case ChatMessage.parsingErrorKey:
            return zh ? "解析错误" : "Parsing Error"
        case ChatMessage.authenticationErrorKey:
            return zh ? "认证失败" : "Authentication Failed"
        case ChatMessage.quotaExceededErrorKey:
            return zh ? "配额已超限" : "Quota Exceeded"
        case ChatMessage.modelNotAvailableErrorKey:
            return zh ? "模型不可用" : "Model Not Available"
        case ChatMessage.loadingLocalModelFailedSystemContentKey:
            return zh ? "本地模型加载失败" : "Local Model Load Failed"
        default:
            return titleText
        }
    }

    private var errorDescription: String {
        let c = message.content
        switch c {
        case ChatMessage.apiRequestFailedErrorKey:
            return zh ? "无法完成 API 请求，请检查网络连接或稍后重试。" : "Unable to complete the API request. Please check your network connection or try again later."
        case ChatMessage.networkConnectionErrorKey:
            return zh ? "无法连接到服务器，请检查网络设置。" : "Cannot connect to the server. Please check your network settings."
        case ChatMessage.parsingErrorKey:
            return zh ? "无法解析服务器响应，可能是数据格式不正确。" : "Unable to parse the server response. The data format might be incorrect."
        case ChatMessage.authenticationErrorKey:
            return zh ? "API Key 无效或已过期，请检查配置。" : "Invalid or expired API Key. Please check your configuration."
        case ChatMessage.quotaExceededErrorKey:
            return zh ? "已达到使用配额上限，请检查账户状态。" : "Usage quota has been reached. Please check your account status."
        case ChatMessage.modelNotAvailableErrorKey:
            return zh ? "所选模型当前不可用，请尝试其他模型。" : "The selected model is currently unavailable. Please try a different model."
        case ChatMessage.loadingLocalModelFailedSystemContentKey:
            return zh ? "无法加载本地模型，请检查模型文件或尝试其他模型。" : "Unable to load the local model. Please check the model files or try a different model."
        default:
            return ""
        }
    }

    private var errorSuggestion: String {
        let c = message.content
        switch c {
        case ChatMessage.apiRequestFailedErrorKey:
            return zh ? "建议：检查网络连接，或稍后重试" : "Suggestion: Check your network connection or try again later"
        case ChatMessage.networkConnectionErrorKey:
            return zh ? "建议：确认网络设置正确，或切换网络环境" : "Suggestion: Verify network settings or switch to a different network"
        case ChatMessage.parsingErrorKey:
            return zh ? "建议：联系支持团队并提供错误详情" : "Suggestion: Contact support with error details"
        case ChatMessage.authenticationErrorKey:
            return zh ? "建议：更新 API Key 配置" : "Suggestion: Update your API Key configuration"
        case ChatMessage.quotaExceededErrorKey:
            return zh ? "建议：升级计划或等待配额重置" : "Suggestion: Upgrade your plan or wait for quota reset"
        case ChatMessage.modelNotAvailableErrorKey:
            return zh ? "建议：选择其他可用模型" : "Suggestion: Select a different available model"
        case ChatMessage.loadingLocalModelFailedSystemContentKey:
            return zh ? "建议：检查模型文件完整性或重新下载模型" : "Suggestion: Verify model file integrity or re-download the model"
        default:
            return ""
        }
    }

    // MARK: - Header

    private var header: some View {
        MessageHeaderView {
            AppIdentityRow(title: titleText)
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                CopyMessageButton(
                    content: message.content,
                    showFeedback: .constant(false)
                )

                Text(formatTimestamp(message.timestamp))
                    .font(AppUI.Typography.caption2)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

                RawMessageToggleButton(showRawMessage: $showRawMessage)
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}

// MARK: - API Key Missing Error View

/// 当当前供应商未配置 API Key 时，在错误消息中渲染的专用视图。
/// 提供一个简化的「生成式 UI」卡片，支持直接为当前会话所用的供应商填写 API Key。
private struct ApiKeyMissingErrorView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var agentSessionConfig: LLMVM
    @EnvironmentObject private var providerRegistry: LLMProviderRegistry

    let message: ChatMessage

    @State private var currentProviderId: String = ""
    @State private var apiKey: String = ""

    private var languagePreference: LanguagePreference {
        projectVM.languagePreference
    }

    private var titleText: String {
        switch languagePreference {
        case .chinese:
            return "当前未配置 API Key"
        case .english:
            return "API Key is not configured"
        }
    }

    private var descriptionText: String {
        switch languagePreference {
        case .chinese:
            return "请为你要使用的 LLM 供应商填写 API Key。配置完成后，可以重新发送本轮请求。"
        case .english:
            return "Please provide API keys for the LLM providers you want to use. After configuration, you can resend your request."
        }
    }

    private var currentProvider: LLMProviderInfo? {
        providerRegistry.allProviders().first(where: { $0.id == currentProviderId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 错误图标和标题
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.error)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(AppUI.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)

                    Text(descriptionText)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
            }

            // 当前会话所用供应商的 API Key 输入
            if let provider = currentProvider {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(provider.displayName)
                            .font(AppUI.Typography.caption1)
                        Spacer()
                    }
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

                    AppInputField(
                        LocalizedStringKey(
                            languagePreference == .chinese
                                ? "输入 \(provider.displayName) 的 API Key"
                                : "Enter API Key for \(provider.displayName)"
                        ),
                        text: Binding(
                            get: { apiKey },
                            set: { newValue in
                                apiKey = newValue
                                agentSessionConfig.setApiKey(newValue, for: currentProviderId)
                            }
                        ),
                        fieldType: .secure
                    )
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .onAppear {
            // 基于当前对话使用的配置初始化供应商 / API Key
            let config = agentSessionConfig.getCurrentConfig()
            currentProviderId = config.providerId
            apiKey = config.apiKey
        }
    }
}

// MARK: - LLM Inline Config Error View

/// `LLMServiceError` 转为错误消息后的专用说明（占位键由 `ChatMessage` 定义）。
private struct LLMInlineConfigErrorView: View {
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
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppUI.Color.semantic.error)
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
