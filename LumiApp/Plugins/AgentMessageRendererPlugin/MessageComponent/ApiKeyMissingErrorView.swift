import MagicKit
import SwiftUI

/// API Key 缺失错误视图
///
/// 当当前供应商未配置 API Key 时，在错误消息中渲染的专用视图。
/// 提供一个简化的「生成式 UI」卡片，支持直接为当前会话所用的供应商填写 API Key。
struct ApiKeyMissingErrorView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var agentSessionConfig: LLMVM
    @EnvironmentObject private var providerRegistry: LLMProviderRegistry

    let message: ChatMessage

    @State private var currentProviderId: String = ""
    @State private var apiKey: String = ""
    @State private var hasInitialized = false

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
                ErrorIconView(size: 16, weight: .medium)

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
                                saveApiKey(newValue)
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
            guard !hasInitialized else { return }
            hasInitialized = true
            initializeProviderAndApiKey()
        }
        .onChange(of: message.providerId) { _, newProviderId in
            // 当错误消息的 providerId 发生变化时，重新初始化
            if let newProviderId = newProviderId,
               !newProviderId.isEmpty,
               newProviderId != currentProviderId {
                currentProviderId = newProviderId
                reloadApiKeyFromKeychain()
            }
        }
    }

    /// 初始化供应商 ID 和 API Key
    private func initializeProviderAndApiKey() {
        // 优先使用错误消息中保存的 providerId
        if let messageProviderId = message.providerId, !messageProviderId.isEmpty {
            currentProviderId = messageProviderId
        } else {
            // 如果错误消息中没有 providerId，则使用当前全局配置
            let config = agentSessionConfig.getCurrentConfig()
            currentProviderId = config.providerId
        }

        // 从 Keychain 重新加载 API Key
        reloadApiKeyFromKeychain()
    }

    /// 从 Keychain 重新加载 API Key
    private func reloadApiKeyFromKeychain() {
        apiKey = agentSessionConfig.getApiKey(for: currentProviderId)
    }

    /// 保存 API Key 到 Keychain
    private func saveApiKey(_ newValue: String) {
        guard !currentProviderId.isEmpty else { return }
        agentSessionConfig.setApiKey(newValue, for: currentProviderId)
    }
}
