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
            } else if message.content == ChatMessage.loadingLocalModelSystemContentKey
                || message.content == ChatMessage.loadingLocalModelDoneSystemContentKey {
                // 专门的「正在加载/已就绪」本地模型系统消息，展示模型基本信息
                VStack(alignment: .leading, spacing: 4) {
                    header

                    LoadingLocalModelSystemMessageView(message: message)
                        .messageBubbleStyle(role: message.role, isError: false)
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

    // MARK: - Header

    private var header: some View {
        MessageHeaderView {
            AppIdentityRow(
                title: "System",
                titleColor: AppUI.Color.semantic.textSecondary
            )
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
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
                    .font(AppUI.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
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

    private var statusText: String {
        if isLoading {
            return projectVM.languagePreference == .chinese ? "正在加载模型…" : "Loading model…"
        }
        return projectVM.languagePreference == .chinese ? "模型已就绪" : "Model ready"
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
                Text(info.displayName)
                    .font(AppUI.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                if let series = info.series, !series.isEmpty {
                    AppTag(series)
                }
            }

            if !info.description.isEmpty {
                Text(info.description)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
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
            Text(line)
                .font(AppUI.Typography.caption1)
                .foregroundColor(AppUI.Color.semantic.textSecondary)
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
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppUI.Color.semantic.success)
        }
    }
}
