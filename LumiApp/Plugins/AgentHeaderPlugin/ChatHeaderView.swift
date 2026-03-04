import SwiftUI

/// 聊天头部视图
/// 包含项目信息、工具栏按钮和快捷操作，显示在聊天界面顶部
struct ChatHeaderView: View {
    @EnvironmentObject var agentProvider: AgentProvider
    @EnvironmentObject var conversationViewModel: ConversationViewModel

    /// 项目选择器呈现状态绑定
    @Binding var isProjectSelectorPresented: Bool
    /// MCP 设置呈现状态绑定
    @Binding var isMCPSettingsPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 主工具栏：包含应用图标、项目信息和功能按钮
            HStack(spacing: 12) {
                // 应用图标
                Image(systemName: "hammer.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())

                // 项目信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(agentProvider.currentProjectName.isEmpty ? "Dev Assistant" : agentProvider.currentProjectName)
                        .font(DesignTokens.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }

                Spacer()

                // 开启新会话按钮
                newChatButton

                // 风险自动批准开关
                autoApproveToggle

                // 语言选择器
                languageSelector

                // MCP Management Button
                mcpButton

                // 项目管理按钮
                projectButton

                // 设置按钮
                settingsButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            // 项目选择提示：未选择项目时显示
            if !agentProvider.isProjectSelected {
                projectSelectionHint
            }
        }
        .background(DesignTokens.Material.glassThick)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.black.opacity(0.05)),
            alignment: .bottom
        )
    }
}

// MARK: - View

extension ChatHeaderView {
    /// 新会话按钮：点击时调用 conversationViewModel.createNewConversation()
    private var newChatButton: some View {
        Button(action: {
            Task {
                let projectId = agentProvider.isProjectSelected ? agentProvider.currentProjectPath : nil
                await conversationViewModel.createNewConversation(projectId: projectId)
            }
        }) {
            Image(systemName: "plus.circle")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("开启新会话")
    }

    /// 自动批准开关：控制是否自动批准高风险命令
    private var autoApproveToggle: some View {
        HStack(spacing: 6) {
            Text("Auto")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Toggle("", isOn: Binding(
                get: { agentProvider.autoApproveRisk },
                set: { agentProvider.setAutoApproveRisk($0) }
            ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.05))
        .cornerRadius(6)
        .help("自动批准高风险命令")
    }

    /// 语言选择器：下拉菜单选择 AI 响应语言
    private var languageSelector: some View {
        Menu {
            ForEach(LanguagePreference.allCases) { lang in
                Button(action: {
                    withAnimation {
                        agentProvider.setLanguagePreference(lang)
                    }
                }) {
                    HStack {
                        Text(lang.displayName)
                        if agentProvider.languagePreference == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                Text(agentProvider.languagePreference.displayName)
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 70)
    }

    /// MCP 管理按钮：打开 MCP 服务器设置
    private var mcpButton: some View {
        Button(action: {
            isMCPSettingsPresented = true
        }) {
            Image(systemName: "server.rack")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    /// 项目管理按钮：打开项目选择器
    private var projectButton: some View {
        Button(action: {
            isProjectSelectorPresented = true
        }) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    /// 设置按钮：打开应用设置
    private var settingsButton: some View {
        Button(action: {
            NotificationCenter.postOpenSettings()
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    /// 项目选择提示：未选择项目时显示的提示信息
    private var projectSelectionHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)

            Text("请先选择一个项目才能开始对话")
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Spacer()

            Button(action: {
                isProjectSelectorPresented = true
            }) {
                Text("选择项目")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.05))
    }
}

// MARK: - Preview

#if os(macOS)
#Preview("聊天头部 - 默认状态") {
    ChatHeaderView(
        isProjectSelectorPresented: .constant(false),
        isMCPSettingsPresented: .constant(false)
    )
    .frame(width: 800)
    .inRootView("Preview")
}

#Preview("聊天头部 - 窄屏") {
    ChatHeaderView(
        isProjectSelectorPresented: .constant(false),
        isMCPSettingsPresented: .constant(false)
    )
    .frame(width: 600)
    .inRootView("Preview")
}
#endif
