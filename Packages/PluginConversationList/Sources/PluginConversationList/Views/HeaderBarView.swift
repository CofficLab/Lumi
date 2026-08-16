import SwiftUI

/// 对话列表顶部标题栏：根据 scopeToCurrentProject 与当前项目动态显示。
struct HeaderBarView: View {
    /// 是否仅展示当前项目下的会话。
    let scopeToCurrentProject: Bool
    /// 用于解析当前项目名称（当 `scopeToCurrentProject == true` 时使用）。
    let context: ConversationListContext

    var body: some View {
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

    private var title: String {
        if scopeToCurrentProject {
            let projectName = context.currentProjectName ?? "—"
            return String(format: "项目对话 (%@)", projectName)
        }
        return "所有项目的对话"
    }
}
