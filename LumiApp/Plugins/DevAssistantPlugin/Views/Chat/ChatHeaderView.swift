import SwiftUI

/// 聊天头部视图 - 包含项目信息、工具栏按钮和快捷操作
struct ChatHeaderView: View {
    @ObservedObject var viewModel: AssistantViewModel
    @Binding var isProjectSelectorPresented: Bool
    @Binding var isMCPSettingsPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 主工具栏

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
                    Text(viewModel.currentProjectName.isEmpty ? "Dev Assistant" : viewModel.currentProjectName)
                        .font(DesignTokens.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text(viewModel.currentProjectPath.isEmpty ? "Ready to help" : viewModel.currentProjectPath)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

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
            .padding(.vertical, 12)

            // MARK: - 项目选择提示

            if !viewModel.isProjectSelected {
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

    // MARK: - Auto Approve Toggle

    private var autoApproveToggle: some View {
        HStack(spacing: 6) {
            Text("Auto")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Toggle("", isOn: $viewModel.autoApproveRisk)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.05))
        .cornerRadius(6)
        .help("Automatically approve high-risk commands")
    }

    // MARK: - Language Selector

    private var languageSelector: some View {
        Menu {
            ForEach(LanguagePreference.allCases) { lang in
                Button(action: {
                    withAnimation {
                        viewModel.languagePreference = lang
                    }
                }) {
                    HStack {
                        Text(lang.displayName)
                        if viewModel.languagePreference == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                Text(viewModel.languagePreference.displayName)
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

    // MARK: - MCP Button

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

    // MARK: - Project Button

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

    // MARK: - Settings Button

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

    // MARK: - Project Selection Hint

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

#Preview {
    ChatHeaderView(
        viewModel: AssistantViewModel(),
        isProjectSelectorPresented: .constant(false),
        isMCPSettingsPresented: .constant(false)
    )
    .frame(width: 800)
}
