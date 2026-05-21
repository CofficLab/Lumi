import SwiftUI

/// 编辑器 Tab Header 视图
///
/// 渲染 Tab 栏 UI，并嵌入 `EditorTabStripCoordinator` 实现
/// 标签页的自动保存和项目切换时的恢复。
struct EditorTabHeaderView: View {

    // MARK: - 属性

    @EnvironmentObject var editorVM: WindowEditorVM
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject private var themeVM: AppThemeVM

    @State private var draggedTabSessionID: UUID?

    /// 标签页持久化协调器
    @StateObject private var coordinator = EditorTabStripCoordinator()

    var service: EditorService { editorVM.service }

    // ⚠️ sessionStore 用于 EditorTabStripCoordinator 的 Combine 订阅（$tabs, $activeSessionID），
    // 这些 Publisher 无法通过门面方法转发。
    var sessionStore: EditorSessionStore { service.sessionStore }

    // MARK: - Body

    var body: some View {
        ZStack {
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
                openFile: { [weak editorVM, weak projectVM] url in
                    let projectPath = projectVM?.currentProjectPath
                    await editorVM?.service.refreshProjectContext(for: projectPath)
                    editorVM?.service.open(at: url)
                },
                openFileSessionOnly: { [weak editorVM] url in
                    editorVM?.service.openFile(at: url)
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
                sessionStore: sessionStore,
                openFile: { [weak editorVM, weak projectVM] url in
                    let projectPath = projectVM?.currentProjectPath
                    await editorVM?.service.refreshProjectContext(for: projectPath)
                    editorVM?.service.open(at: url)
                },
                openFileSessionOnly: { [weak editorVM] url in
                    editorVM?.service.openFile(at: url)
                }
            )
        }
        .onCurrentFileDidChange { path in
            handleCurrentFileDidChange(path: path)
        }
    }

    // MARK: - 计算属性

    private var theme: any LumiAppChromeTheme {
        themeVM.activeChromeTheme
    }

    private var visibleTabs: [EditorTab] {
        service.tabs
    }

    // MARK: - 子视图

    private var tabList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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

    // MARK: - 操作方法

    /// 开始拖拽标签页
    private func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    /// 将拖拽的标签页放入当前位置
    private func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        _ = service.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetTab?.sessionID
        )
    }

    /// 处理 SetCurrentFileTool 发出的通知，同步到编辑器
    private func handleCurrentFileDidChange(path: String) {
        // 如果路径与当前文件相同，无需切换
        guard service.currentFileURL?.path != path else { return }

        // 验证文件存在
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        Task { @MainActor in
            await service.refreshProjectContext(for: projectVM.currentProjectPath)
            service.open(at: url)
        }
    }
}
