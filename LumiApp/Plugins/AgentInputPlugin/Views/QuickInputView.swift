import MagicKit
import SwiftUI

/// 快捷输入视图 - 提供所有快捷短语的快速输入
struct QuickInputView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "⚡"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 输入框本地状态 ViewModel
    @ObservedObject var inputViewModel: InputViewModel

    /// 会话服务 - 用于获取快捷短语
    @EnvironmentObject var conversationTurnServices: ConversationTurnServices

    /// 项目管理 ViewModel
    @EnvironmentObject var ProjectVM: ProjectVM

    var body: some View {
        HStack(spacing: 6) {
            // 从 PromptService 获取所有快捷短语
            let phrases = conversationTurnServices.promptService.getQuickPhrases(
                projectName: ProjectVM.currentProjectName,
                projectPath: ProjectVM.currentProjectPath
            )

            // 展示所有短语
            ForEach(phrases, id: \.title) { phrase in
                commitButton(
                    title: phrase.title,
                    icon: phrase.icon,
                    prompt: phrase.prompt
                )
            }

            Spacer()
        }
    }

    /// Commit 按钮
    /// - Parameters:
    ///   - title: 按钮标题
    ///   - icon: SF Symbols 图标名称
    ///   - prompt: 点击后填入的提示词
    private func commitButton(title: String, icon: String, prompt: String) -> some View {
        Button(action: {
            inputViewModel.set(prompt)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(String(localized: "Fill Prompt Hint", table: "AgentInput"))
    }
}

// MARK: - Preview

#Preview {
    QuickInputView(inputViewModel: InputViewModel())
        .padding()
        .inRootView()
}
