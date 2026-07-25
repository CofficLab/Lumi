import Combine
import LumiKernel
import LumiUI
import SwiftUI

/// 编辑器 Tab Header 视图
///
/// 渲染 Tab 栏 UI，并嵌入 `StripCoordinator` 实现
/// 标签页的自动保存和项目切换时的恢复。
///
/// 编辑器协同能力通过 kernel 的 `EditorTabStripCoordination` 协议消费,
/// 本视图不依赖具体编辑器服务实现。
public struct HeaderView: View {

    // MARK: - 属性

    let kernel: LumiKernel
    @EnvironmentObject private var themeVM: AppThemeVM
    @State private var draggedTabSessionID: UUID?

    /// 编辑器协同能力(从内核解析;若未注册则相关操作降级为空操作)。
    private let coordination: (any EditorTabStripCoordination)?
    /// 标签状态流(init 时捕获一次,避免 body 重建 publisher 触发死循环)。
    private let statePublisher: AnyPublisher<TabStripState, Never>

    /// 当前标签状态(由 publisher 驱动)。
    @State private var state: TabStripState = TabStripState(tabs: [], activeSessionID: nil)

    /// 标签页持久化协调器
    @StateObject private var coordinator = StripCoordinator()

    private var currentProjectPath: String {
        kernel.project?.currentProject?.path ?? ""
    }

    public init(coordination: (any EditorTabStripCoordination)?, kernel: LumiKernel) {
        self.coordination = coordination
        self.kernel = kernel
        self.statePublisher = coordination?.tabStripStatePublisher
            ?? Empty().eraseToAnyPublisher()
    }

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
        .onReceive(statePublisher) { newState in
            state = newState
        }
        .onAppear {
            guard let coordination else { return }
            coordinator.startObserving(
                coordination: coordination,
                projectPathProvider: {
                    kernel.project?.currentProject?.path ?? ""
                },
                openFile: { [weak coordination] url in
                    coordination?.openFile(at: url)
                },
                openFileSessionOnly: { [weak coordination] url in
                    coordination?.openFileSessionInBackground(at: url)
                }
            )
        }
        .onDisappear {
            guard let coordination else { return }
            coordinator.stopObserving(
                coordination: coordination,
                projectPath: currentProjectPath
            )
        }
        .onChange(of: currentProjectPath) { oldPath, newPath in
            guard let coordination else { return }
            coordinator.handleProjectPathChange(
                oldPath: oldPath,
                newPath: newPath,
                coordination: coordination,
                openFile: { [weak coordination] url in
                    coordination?.openFile(at: url)
                },
                openFileSessionOnly: { [weak coordination] url in
                    coordination?.openFileSessionInBackground(at: url)
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

    private var visibleTabs: [TabDescriptor] {
        guard let projectRoot = normalizedProjectRoot else { return [] }
        return state.tabs.filter { tab in
            guard let fileURL = tab.fileURL else { return false }
            return isFile(fileURL, inside: projectRoot)
        }
    }

    /// 当前激活的会话 ID，用于驱动 tab 栏自动滚动到激活 tab
    private var activeSessionID: UUID? {
        state.activeSessionID
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
                            coordination: coordination,
                            allTabs: visibleTabs,
                            activeSessionID: activeSessionID,
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
            }
            .onChange(of: activeSessionID) { _, newSessionID in
                guard let newSessionID else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newSessionID, anchor: .center)
                }
            }
            .onAppear {
                guard let activeSessionID else { return }
                proxy.scrollTo(activeSessionID, anchor: .center)
            }
        }
    }

    // MARK: - 操作方法

    /// 开始拖拽标签页
    private func beginTabDrag(_ tab: TabDescriptor) {
        draggedTabSessionID = tab.sessionID
    }

    /// 将拖拽的标签页放入当前位置
    private func dropDraggedTabInActiveStrip(before targetTab: TabDescriptor?) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        coordination?.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetTab?.sessionID
        )
    }

    /// 处理 SetCurrentFileTool 发出的通知，同步到编辑器
    private func handleCurrentFileDidChange(path: String) {
        guard let projectRoot = normalizedProjectRoot else { return }
        let targetPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard targetPath == projectRoot || targetPath.hasPrefix(projectRoot + "/") else { return }

        // 验证文件存在
        guard FileManager.default.fileExists(atPath: path) else { return }

        let url = URL(fileURLWithPath: path)
        coordination?.openFile(at: url)
    }

    private func isFile(_ fileURL: URL, inside projectRoot: String) -> Bool {
        let normalized = fileURL.standardizedFileURL.path
        return normalized == projectRoot || normalized.hasPrefix(projectRoot + "/")
    }
}
