import MagicKit
import SwiftUI

// MARK: - System Message
//
/// 负责完整渲染一条系统消息（包含头部与正文）
struct SystemMessage: View {
    let message: ChatMessage
    @Binding var showRawMessage: Bool

    @EnvironmentObject private var providerRegistry: LLMProviderRegistry

    var body: some View {
        Group {
            if message.isToolOutput {
                // 工具输出消息：使用专用样式，不展示 System 头部
                VStack(alignment: .leading, spacing: 4) {
                    RoleLabel.tool
                    ToolOutputView(message: message)
                }
            } else if message.content == ChatMessage.apiKeyMissingSystemContentKey {
                // 专门的「API Key 未配置」系统消息，内嵌供应商 API Key 配置卡片
                VStack(alignment: .leading, spacing: 4) {
                    header

                    ApiKeyMissingSystemMessageView()
                        .messageBubbleStyle(role: message.role, isError: true)
                }
            } else if message.content == ChatMessage.loadingLocalModelSystemContentKey
                || message.content == ChatMessage.loadingLocalModelDoneSystemContentKey
                || message.content == ChatMessage.loadingLocalModelFailedSystemContentKey {
                // 专门的「正在加载/已就绪/加载失败」本地模型系统消息，展示模型基本信息
                VStack(alignment: .leading, spacing: 4) {
                    header

                    LoadingLocalModelSystemMessageView(message: message)
                        .messageBubbleStyle(role: message.role, isError: message.content == ChatMessage.loadingLocalModelFailedSystemContentKey)
                }
            } else if Self.isLLMInlineConfigError(message) {
                VStack(alignment: .leading, spacing: 4) {
                    header

                    LLMInlineConfigErrorView(message: message)
                        .messageBubbleStyle(role: message.role, isError: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    header

                    MarkdownView(
                        message: message,
                        showRawMessage: showRawMessage,
                        isCollapsible: false,
                        isExpanded: true,
                        onToggleExpand: {}
                    )
                    .messageBubbleStyle(role: message.role, isError: message.isError)
                }
            }
        }
    }

    /// LLM 配置 / 供应商 / Base URL 等占位系统消息（`ChatMessage` 的 `content` 为稳定键）。
    private static func isLLMInlineConfigError(_ message: ChatMessage) -> Bool {
        let c = message.content
        if c == ChatMessage.llmModelEmptyContentKey { return true }
        if c == ChatMessage.llmProviderIdEmptyContentKey { return true }
        if c == ChatMessage.llmTemperatureInvalidContentKey { return true }
        if c == ChatMessage.llmMaxTokensInvalidContentKey { return true }
        if c == ChatMessage.llmProviderNotFoundContentKey { return true }
        return c.hasPrefix(ChatMessage.llmInvalidBaseURLContentKey)
    }

    // MARK: - Header

    private var header: some View {
        MessageHeaderView {
            HStack(alignment: .center, spacing: 4) {
                Text("System")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                Text(formatTimestamp(message.timestamp))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

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

// MARK: - LLM Inline Config Error View

/// `LLMServiceError` 转为系统消息后的专用说明（占位键由 `ChatMessage` 定义）。
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
                    .foregroundColor(DesignTokens.Color.semantic.error)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    if !detailText.isEmpty {
                        Text(detailText)
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

// MARK: - API Key Missing System Message View

/// 当当前供应商未配置 API Key 时，在系统消息中渲染的专用视图。
/// 提供一个简化的「生成式 UI」卡片，支持直接为当前会话所用的供应商填写 API Key。
private struct ApiKeyMissingSystemMessageView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var agentSessionConfig: LLMVM
    @EnvironmentObject private var providerRegistry: LLMProviderRegistry

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
            // 标题与说明
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(DesignTokens.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text(descriptionText)
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            // 当前会话所用供应商的 API Key 输入
            if let provider = currentProvider {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 12))
                        Text(provider.displayName)
                            .font(DesignTokens.Typography.caption1)
                        Spacer()
                    }
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

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
        .onAppear {
            // 基于当前对话使用的配置初始化供应商 / API Key
            let config = agentSessionConfig.getCurrentConfig()
            currentProviderId = config.providerId
            apiKey = config.apiKey
        }
    }
}

// MARK: - Loading Local Model System Message View

/// 本地模型正在加载或已就绪时，在系统消息中渲染的专用视图，展示状态与 LocalModelInfo 字段。
private struct LoadingLocalModelSystemMessageView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var providerRegistry: LLMProviderRegistry

    let message: ChatMessage

    @State private var localModelInfo: LocalModelInfo?

    private var isLoading: Bool {
        message.content == ChatMessage.loadingLocalModelSystemContentKey
    }

    private var isFailed: Bool {
        message.content == ChatMessage.loadingLocalModelFailedSystemContentKey
    }

    private var statusText: String {
        if isLoading {
            return projectVM.languagePreference == .chinese ? "正在加载模型…" : "Loading model…"
        }
        if isFailed {
            return projectVM.languagePreference == .chinese ? "加载失败" : "Load failed"
        }
        return projectVM.languagePreference == .chinese ? "模型已就绪" : "Model ready"
    }

    private var provider: LLMProviderInfo? {
        guard let id = message.providerId else { return nil }
        return providerRegistry.allProviders().first(where: { $0.id == id })
    }

    private var modelInfoFallbackLine: String? {
        let name = message.modelName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !(name?.isEmpty ?? true) else { return nil }
        if let p = provider {
            return "\(p.displayName) · \(name ?? "")"
        }
        return name
    }

    private func ramText(minRAM: Int) -> String {
        projectVM.languagePreference == .chinese ? "\(minRAM) GB RAM 最低" : "\(minRAM) GB RAM min"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                statusIcon
                Text(statusText)
                    .font(DesignTokens.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Spacer(minLength: 0)
            }

            if let info = localModelInfo {
                modelInfoContent(info)
            } else if let line = modelInfoFallbackLine, !line.isEmpty {
                fallbackModelLine(line)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .task(id: "\(message.providerId ?? "")-\(message.modelName ?? "")") {
            await loadLocalModelInfo()
        }
    }

    private func loadLocalModelInfo() async {
        guard let providerId = message.providerId, let modelId = message.modelName else {
            localModelInfo = nil
            return
        }
        guard let provider = providerRegistry.createProvider(id: providerId) as? any SuperLocalLLMProvider else {
            localModelInfo = nil
            return
        }
        let models = await provider.getAvailableModels()
        localModelInfo = models.first(where: { $0.id == modelId })
    }

    @ViewBuilder
    private func modelInfoContent(_ info: LocalModelInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let p = provider {
                    Image(systemName: p.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                Text(info.displayName)
                    .font(DesignTokens.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                if let series = info.series, !series.isEmpty {
                    AppTag(series)
                }
            }

            if !info.description.isEmpty {
                Text(info.description)
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                AppTag(info.size, systemImage: "internaldrive")
                AppTag(ramText(minRAM: info.minRAM), systemImage: "memorychip")
                if info.supportsVision {
                    AppTag(
                        projectVM.languagePreference == .chinese ? "视觉" : "Vision",
                        systemImage: "eye",
                        style: .accent
                    )
                }
                if info.supportsTools {
                    AppTag(
                        projectVM.languagePreference == .chinese ? "工具" : "Tools",
                        systemImage: "wrench.and.screwdriver",
                        style: .accent
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func fallbackModelLine(_ line: String) -> some View {
        HStack(spacing: 6) {
            if let p = provider {
                Image(systemName: p.iconName)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            Text(line)
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isLoading {
            ProgressView()
                .scaleEffect(0.75)
                .controlSize(.small)
        } else if isFailed {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Color.semantic.error)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Color.semantic.success)
        }
    }
}
