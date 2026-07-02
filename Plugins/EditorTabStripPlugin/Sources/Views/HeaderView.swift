import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

/// 编辑器 Tab Header 视图
///
/// 渲染 Tab 栏 UI，并嵌入 `StripCoordinator` 实现
/// 标签页的自动保存和项目切换时的恢复。
public struct HeaderView: View {

    // MARK: - 属性

    @EnvironmentObject private var themeVM: AppThemeVM
    @State private var draggedTabSessionID: UUID?
    @ObservedObject private var service: EditorService

    /// 标签页持久化协调器
    @StateObject private var coordinator = StripCoordinator()

    private var currentProjectPath: String {
        LumiCore.projectState?.currentProject?.path ?? ""
    }

    public init(service: EditorService) {
        self._service = ObservedObject(wrappedValue: service)
    }

    // ⚠️ sessionStore 用于 StripCoordinator 的 Combine 订阅（$tabs, $activeSessionID），
    // 这些 Publisher 无法通过门面方法转发。
    public var sessionStore: EditorSessionStore { service.sessionStore }

    // MARK: - Body

    public var body: some View {
        AppToolbarContainer(
            height: 40,
            backgroundStyle: .panel,
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        ) {
            if !visibleTabs.isEmpty {
                tabListContent
            } else {
                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
        .borderBottom()
        .onAppear {
            coordinator.startObserving(
                sessionStore: sessionStore,
                projectPathProvider: {
                    LumiCore.projectState?.currentProject?.path ?? ""
                },
                openFile: { [weak service] url in
                    let projectPath = LumiCore.projectState?.currentProject?.path
                    Task { @MainActor in
                        await service?.refreshProjectContext(for: projectPath)
                        service?.sessions.open(at: url)
                    }
                },
                openFileSessionOnly: { [weak service] url in
                    service?.sessions.openFileSessionInBackground(at: url)
                }
            )
        }
        .onDisappear {
            coordinator.stopObserving(
                sessionStore: sessionStore,
                projectPath: currentProjectPath
            )
        }
        .onChange(of: currentProjectPath) { oldPath, newPath in
            coordinator.handleProjectPathChange(
                oldPath: oldPath,
                newPath: newPath,
                sessionStore: sessionStore,
                openFile: { [weak service] url in
                    let projectPath = LumiCore.projectState?.currentProject?.path
                    Task { @MainActor in
                        await service?.refreshProjectContext(for: projectPath)
                        service?.sessions.open(at: url)
                    }
                },
                openFileSessionOnly: { [weak service] url in
                    service?.sessions.openFileSessionInBackground(at: url)
                }
            )
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .currentFileDidChange)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let path = notification.userInfo?["path"] as? String else { return }
            handleCurrentFileDidChange(path: path)
        }
    }

    // MARK: - 计算属性

    private var theme: any LumiAppChromeTheme {
        themeVM.activeChromeTheme
    }

    private var visibleTabs: [EditorTab] {
        guard let projectRoot = normalizedProjectRoot else { return [] }
        return service.sessions.tabs.filter { tab in
            guard let fileURL = tab.fileURL else { return false }
            return isFile(fileURL, inside: projectRoot)
        }
    }

    private var normalizedProjectRoot: String? {
        let path = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    // MARK: - 子视图

    private var tabListContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(visibleTabs) { tab in
                    ItemView(
                        service: service,
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
            // 如果小一些，整个tab列表的点击事件就失效，不知道为什么
        }
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

        _ = service.sessions.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetTab?.sessionID
        )
    }

    /// 处理 SetCurrentFileTool 发出的通知，同步到编辑器
    private func handleCurrentFileDidChange(path: String) {
        guard let projectRoot = normalizedProjectRoot else { return }
        let targetPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard targetPath == projectRoot || targetPath.hasPrefix(projectRoot + "/") else { return }
        // 如果路径与当前文件相同，无需切换
        guard service.files.currentFileURL?.path != path else { return }

        // 验证文件存在
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        Task { @MainActor in
            await service.refreshProjectContext(for: currentProjectPath)
            service.sessions.open(at: url)
        }
    }

    private func isFile(_ fileURL: URL, inside projectRoot: String) -> Bool {
        let normalized = fileURL.standardizedFileURL.path
        return normalized == projectRoot || normalized.hasPrefix(projectRoot + "/")
    }
}
