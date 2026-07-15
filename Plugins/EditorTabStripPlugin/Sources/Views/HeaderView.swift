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

    let lumiCore: LumiCoreAccessing
    @EnvironmentObject private var themeVM: AppThemeVM
    @State private var draggedTabSessionID: UUID?
    @ObservedObject private var service: EditorService

    /// 标签页持久化协调器
    @StateObject private var coordinator = StripCoordinator()

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public init(service: EditorService, lumiCore: LumiCoreAccessing) {
        self._service = ObservedObject(wrappedValue: service)
        self.lumiCore = lumiCore
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
                    lumiCore.projectState?.currentProject?.path ?? ""
                },
                openFile: { [weak service] url in
                    let projectPath = lumiCore.projectState?.currentProject?.path
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
                    let projectPath = lumiCore.projectState?.currentProject?.path
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

    /// 当前激活的会话 ID，用于驱动 tab 栏自动滚动到激活 tab
    private var activeSessionID: UUID? {
        service.sessions.activeSessionID
    }

    private var normalizedProjectRoot: String? {
        let path = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    // MARK: - 子视图

    private var tabListContent: some View {
        ScrollViewReader { proxy in
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
                        .id(tab.sessionID)
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
            // 激活 tab 变化时自动滚动到可视区域（对齐 VS Code 体验）：
            // 覆盖新打开文件、点击切换、外部命令切换等所有场景。
            .onChange(of: activeSessionID) { _, newSessionID in
                guard let newSessionID else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newSessionID, anchor: .center)
                }
            }
            // 首次出现时（含从磁盘恢复标签后）定位到激活 tab
            .onAppear {
                guard let activeSessionID else { return }
                proxy.scrollTo(activeSessionID, anchor: .center)
            }
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
