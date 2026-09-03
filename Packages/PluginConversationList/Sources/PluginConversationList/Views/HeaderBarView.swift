import SwiftUI

/// 对话列表顶部标题栏：根据 scopeToCurrentProject 与当前项目动态显示。
struct HeaderBarView: View {
    /// 是否仅展示当前项目下的会话。
    let scopeToCurrentProject: Bool
    /// 用于解析当前项目名称（当 `scopeToCurrentProject == true` 时使用）。
    @ObservedObject private var context: ConversationListContext

    init(scopeToCurrentProject: Bool, context: ConversationListContext) {
        self.scopeToCurrentProject = scopeToCurrentProject
        self._context = ObservedObject(wrappedValue: context)
    }

    /// 全库对话是否来自多个项目。
    /// 默认隐藏，避免数据加载期间短暂显示单项目场景下无意义的提示。
    @State private var hasMultipleProjects = false

    var body: some View {
        Group {
            if scopeToCurrentProject || hasMultipleProjects {
                HStack(spacing: 6) {
                    Image(systemName: scopeToCurrentProject ? "folder.fill" : "tray.full.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.06))
            }
        }
        .task {
            await refreshProjectVisibility()
        }
        .onChange(of: context.conversationsRevision) { _, _ in
            Task { await refreshProjectVisibility() }
        }
    }

    private var title: String {
        if scopeToCurrentProject {
            let projectName = context.currentProjectName ?? "—"
            return String(format: "项目对话 (%@)", projectName)
        }
        return "所有项目的对话"
    }

    /// 只有全库对话来自多个项目时，才需要提示当前列表是跨项目的。
    private func refreshProjectVisibility() async {
        guard !scopeToCurrentProject else { return }
        hasMultipleProjects = await context.conversations.conversationProjectCount() > 1
    }
}
