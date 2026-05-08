import MagicKit
import SwiftUI

/// 编辑器 Tab Header 视图
///
/// 渲染 Tab 栏 UI，并嵌入 `EditorTabStripCoordinator` 实现
/// 标签页的自动保存和项目切换时的恢复。
struct EditorTabHeaderView: View {
    @EnvironmentObject var editorVM: EditorVM
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject private var themeVM: ThemeVM
    @State private var draggedTabSessionID: UUID?

    /// 标签页持久化协调器
    @StateObject private var coordinator = EditorTabStripCoordinator()

    var service: EditorService { editorVM.service }

    // ⚠️ sessionStore 用于 EditorTabStripCoordinator 的 Combine 订阅（$tabs, $activeSessionID），
    // 这些 Publisher 无法通过门面方法转发。
    var sessionStore: EditorSessionStore { service.sessionStore }

    // MARK: - Body

    var body: some View {
        Group {
            if !visibleTabs.isEmpty {
                tabList
            }
        }
        .onAppear {
            coordinator.startObserving(
                sessionStore: sessionStore,
                projectPathProvider: { [weak projectVM] in
                    projectVM?.currentProjectPath ?? ""
                },
                openFile: { [weak editorVM] url in
                    editorVM?.service.openAndRenderFile(at: url)
                }
            )
        }
        .onDisappear {
            coordinator.stopObserving(
                sessionStore: sessionStore,
                projectPath: projectVM.currentProjectPath
            )
        }
        .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
            coordinator.handleProjectPathChange(
                oldPath: oldPath,
                newPath: newPath,
                sessionStore: sessionStore
            ) { [weak editorVM] url in
                editorVM?.service.openAndRenderFile(at: url)
            }
        }
    }

    // MARK: - 子视图

    private var tabList: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 0) {
                ForEach(visibleTabs) { tab in
                    EditorTabItemView(
                        tab: tab,
                        theme: theme,
                        onStartDrag: beginTabDrag,
                        onDropBefore: dropDraggedTabInActiveStrip
                    )
                }

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

    // MARK: - 计算属性

    private var theme: any SuperTheme {
        themeVM.activeAppTheme
    }

    private var visibleTabs: [EditorTab] {
        service.tabs
    }

    // MARK: - 操作

    private func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    private func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        _ = service.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetTab?.sessionID
        )
    }
}
