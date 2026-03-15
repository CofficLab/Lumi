import OSLog
import MagicKit
import SwiftData
import SwiftUI

/// 聊天头部视图
/// 包含项目信息、工具栏按钮和快捷操作，显示在聊天界面顶部
struct ChatHeaderView: View, SuperLog {
    nonisolated static let emoji = "📇"
    nonisolated static let verbose = true

    @EnvironmentObject var agentProvider: AgentVM
    @EnvironmentObject var ProjectVM: ProjectVM

    /// SwiftData 模型上下文
    @Environment(\.modelContext) private var modelContext

    /// 项目选择器呈现状态
    @State private var isProjectSelectorPresented = false

    /// 图标尺寸常量
    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            // 主工具栏：包含应用图标、项目信息和功能按钮
            HStack(spacing: 12) {
                // 应用图标
                Image(systemName: "hammer.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.accentColor)
                    .padding(4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())

                // 项目信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(agentProvider.currentProjectName.isEmpty ? "Lumi" : agentProvider.currentProjectName)
                        .font(DesignTokens.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }

                Spacer()

                // 工具栏按钮组
                HStack(spacing: 12) {
                    NewChatButton()
                    AutoApproveToggle()
                    LanguageSelector()
                    ProjectButton()
                    SettingsButton()
                }
            }
            .padding(.horizontal, 16)

            // 项目选择提示：未选择项目时显示
            if !agentProvider.isProjectSelected {
                projectSelectionHint
            }
        }
        .popover(isPresented: $isProjectSelectorPresented, arrowEdge: .top) {
            ProjectSelectorView(isPresented: $isProjectSelectorPresented)
                .frame(width: 400, height: 500)
        }
        .onOpenProjectSelector {
            isProjectSelectorPresented = true
        }
    }
}

// MARK: - View

extension ChatHeaderView {
    /// 项目选择提示：未选择项目时显示的提示条
    private var projectSelectionHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 12))

            Text("请选择一个项目以开始")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Spacer()

            Button(action: {
                isProjectSelectorPresented = true
            }) {
                Text("选择项目")
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - Preview

#Preview("Chat Header") {
    ChatHeaderView()
        .padding()
        .background(Color.black)
        .inRootView()
}
