import MagicKit
import SwiftUI

/// 编辑器 Tab Header 视图
struct EditorTabHeaderView: View {
    @EnvironmentObject var editorVM: EditorVM
    @EnvironmentObject private var themeVM: ThemeVM
    @State private var draggedTabSessionID: EditorSession.ID?

    var body: some View {
        if !visibleTabs.isEmpty {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(visibleTabs) { tab in
                        EditorTabItemView(
                            tab: tab,
                            isActive: tab.sessionID == visibleActiveSessionID,
                            theme: theme,
                            onStartDrag: beginTabDrag,
                            onDropBefore: dropDraggedTabInActiveStrip
                        )
                    }

                    // Use a small explicit end drop zone so the scroll
                    // content does not become one oversized hit target.
                    Color.clear
                        .frame(width: 24, height: 28)
                        .contentShape(Rectangle())
                        .onDrop(of: [.plainText], isTargeted: nil) { _ in
                            dropDraggedTabInActiveStrip(before: nil)
                            return true
                        }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            // 如果小一些，整个tab列表的点击事件就失效，不知道为什么
            .frame(height: 40)
            .background(theme.workspaceBackgroundColor())
        }
    }

    var service: EditorService { editorVM.service }
    var sessionStore: EditorSessionStore { service.sessionStore }

    private var theme: any SuperTheme {
        themeVM.activeAppTheme
    }

    private var visibleTabs: [EditorTab] {
        sessionStore.tabs
    }

    private var visibleActiveSessionID: EditorSession.ID? {
        sessionStore.activeSessionID
    }

    private func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    private func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        _ = sessionStore.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetTab?.sessionID
        )
    }
}
