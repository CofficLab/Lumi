import SwiftUI
import MagicKit

/// 单个标签页视图：关闭按钮默认隐藏，hover 或激活时显示
///
/// 点击和关闭操作通过 EnvironmentObject 中的 `editorVM` / `projectVM` 直接执行，
/// 不再依赖闭包传递。
struct HoverRevealButton: View {
    @EnvironmentObject var editorVM: EditorVM
    @EnvironmentObject var projectVM: ProjectVM

    let tab: EditorTab
    let isActive: Bool
    let theme: any SuperTheme

    @State private var isHovered = false

    var body: some View {
        let showClose = isActive || isHovered

        HStack(spacing: 6) {
            if tab.isDirty {
                Circle()
                    .fill(AppUI.Color.semantic.warning)
                    .frame(width: 6, height: 6)
            }

            if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundColor(theme.workspaceTertiaryTextColor())
            }

            Text(tab.title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? theme.workspaceTextColor() : theme.workspaceSecondaryTextColor())
                .lineLimit(1)

            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(theme.workspaceTertiaryTextColor())
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
                .opacity(showClose ? 1 : 0)
                .highPriorityGesture(TapGesture().onEnded {
                    closeSession(tab)
                })
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? theme.workspaceTextColor().opacity(0.07) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? theme.workspaceTextColor().opacity(0.08) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            activateSession(tab)
        }
        .onHover { hovered in
            isHovered = hovered
        }
    }

    // MARK: - 操作

    private func activateSession(_ tab: EditorTab) {
        let sessionStore = editorVM.service.sessionStore
        let workbench = editorVM.service.workbench

        _ = sessionStore.activate(sessionID: tab.sessionID)
        _ = workbench.activate(sessionID: tab.sessionID)
        if let fileURL = tab.fileURL {
            projectVM.selectFile(at: fileURL)
        }
    }

    private func closeSession(_ tab: EditorTab) {
        let sessionStore = editorVM.service.sessionStore
        let workbench = editorVM.service.workbench
        let state = editorVM.service.state

        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        let wasActive = session.id == sessionStore.activeSessionID
        let nextGroupSession = workbench.close(sessionID: session.id)
        if wasActive, state.hasUnsavedChanges {
            state.saveNow()
        }

        let nextSession = sessionStore.close(sessionID: session.id)
        guard wasActive else {
            return
        }

        if let nextFileURL = nextSession?.fileURL {
            projectVM.selectFile(at: nextFileURL)
        } else {
            projectVM.clearFileSelection()
        }
    }
}
