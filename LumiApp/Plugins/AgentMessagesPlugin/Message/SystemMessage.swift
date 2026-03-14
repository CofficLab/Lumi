import MagicKit
import OSLog
import SwiftUI

// MARK: - System Message
//
/// 负责完整渲染一条系统消息（包含头部与正文）
struct SystemMessage: View, SuperLog {
    nonisolated static let emoji = "🛠"
    nonisolated static let verbose = false

    let message: ChatMessage
    @Binding var showRawMessage: Bool

    @State private var isHovered: Bool = false

    @EnvironmentObject private var agentProvider: AgentVM
    @EnvironmentObject private var providerRegistry: ProviderRegistry

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
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    header

                    MarkdownMessageView(
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
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            // 系统标识
            HStack(alignment: .center, spacing: 4) {
                Text("System")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()

            HStack(alignment: .center, spacing: 12) {
                // 时间戳
                Text(formatTimestamp(message.timestamp))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                // 切换原始消息按钮
                RawMessageToggleButton(showRawMessage: $showRawMessage)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .contentShape(Rectangle())
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}

// MARK: - API Key Missing System Message View

/// 当当前供应商未配置 API Key 时，在系统消息中渲染的专用视图。
/// 提供一个简化的「生成式 UI」卡片，支持直接为当前会话所用的供应商填写 API Key。
private struct ApiKeyMissingSystemMessageView: View {
    @EnvironmentObject private var agentProvider: AgentVM
    @EnvironmentObject private var providerRegistry: ProviderRegistry

    @State private var currentProviderId: String = ""
    @State private var apiKey: String = ""

    private var languagePreference: LanguagePreference {
        agentProvider.languagePreference
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

    private var currentProvider: ProviderInfo? {
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

                    SecureField(
                        languagePreference == .chinese
                        ? "输入 \(provider.displayName) 的 API Key"
                        : "Enter API Key for \(provider.displayName)",
                        text: Binding(
                            get: { apiKey },
                            set: { newValue in
                                apiKey = newValue
                                agentProvider.setApiKey(newValue, for: currentProviderId)
                            }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.body)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .fill(DesignTokens.Material.glass)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .padding(.vertical, 2)
            }
        }
        .onAppear {
            // 基于当前对话使用的配置初始化供应商 / API Key
            let config = agentProvider.getCurrentConfig()
            currentProviderId = config.providerId
            apiKey = config.apiKey
        }
    }
}

