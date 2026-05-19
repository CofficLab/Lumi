import Combine
import Foundation
import MagicKit

/// 编辑器标签页持久化协调器
///
/// 订阅 `EditorSessionStore` 的 tabs 变化，自动防抖保存到磁盘；
/// 在项目路径变化时保存旧项目标签并恢复新项目标签。
///
/// 通过 `@EnvironmentObject` 获取 `WindowEditorVM` 和 `WindowProjectVM`，
/// 不依赖任何其他插件。
@MainActor
final class EditorTabStripCoordinator: ObservableObject, SuperLog {
    nonisolated static var emoji: String { "📑" }

    // MARK: - 属性

    private let store = EditorTabStripStore.shared
    private var cancellables = Set<AnyCancellable>()

    /// 是否已完成首次恢复（避免 onAppear 与 onChange 重复恢复）
    private var hasRestored = false

    /// 当前跟踪的项目路径
    private var trackedProjectPath: String = ""

    // MARK: - 订阅

    /// 开始订阅 tabs 变化，自动防抖保存；如果是首次调用且 tabs 为空，立即恢复。
    func startObserving(
        sessionStore: EditorSessionStore,
        projectPathProvider: @MainActor @escaping () -> String,
        openFile: @MainActor @escaping (URL) async -> Void,
        openFileSessionOnly: @MainActor @escaping (URL) -> Void
    ) {
        trackedProjectPath = projectPathProvider()

        // 首次启动且 tabs 为空 → 从磁盘恢复
        if !hasRestored && sessionStore.tabs.isEmpty {
            hasRestored = true
            let path = trackedProjectPath
            Task { @MainActor [weak self] in
                await self?.restoreTabs(
                    forProject: path,
                    openFile: openFile,
                    openFileSessionOnly: openFileSessionOnly
                )
            }
        }

        Publishers.CombineLatest(sessionStore.$tabs, sessionStore.$activeSessionID)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] tabs, activeSessionID in
                guard let self else { return }
                let path = projectPathProvider()
                guard !path.isEmpty else { return }
                let activeTabPath = self.activeTabPath(
                    from: tabs, activeSessionID: activeSessionID
                )
                self.store.saveTabs(
                    projectPath: path,
                    tabs: tabs,
                    activeTabPath: activeTabPath
                )
            }
            .store(in: &cancellables)
    }

    /// 停止订阅并立即保存当前状态
    func stopObserving(
        sessionStore: EditorSessionStore,
        projectPath: String
    ) {
        cancellables.removeAll()

        guard !projectPath.isEmpty else { return }
        let activeTabPath = self.activeTabPath(
            from: sessionStore.tabs,
            activeSessionID: sessionStore.activeSessionID
        )
        store.saveTabs(
            projectPath: projectPath,
            tabs: sessionStore.tabs,
            activeTabPath: activeTabPath
        )
    }

    // MARK: - 项目切换

    /// 处理项目路径变化：保存旧项目 → 恢复新项目
    func handleProjectPathChange(
        oldPath: String,
        newPath: String,
        sessionStore: EditorSessionStore,
        openFile: @MainActor @escaping (URL) async -> Void,
        openFileSessionOnly: @MainActor @escaping (URL) -> Void
    ) {
        // 保存旧项目的标签页
        if !oldPath.isEmpty {
            let activeTabPath = self.activeTabPath(
                from: sessionStore.tabs,
                activeSessionID: sessionStore.activeSessionID
            )
            store.saveTabs(
                projectPath: oldPath,
                tabs: sessionStore.tabs,
                activeTabPath: activeTabPath
            )
        }

        trackedProjectPath = newPath

        // 恢复新项目的标签页
        guard !newPath.isEmpty else { return }
        Task { @MainActor [weak self] in
            await self?.restoreTabs(
                forProject: newPath,
                openFile: openFile,
                openFileSessionOnly: openFileSessionOnly
            )
        }
    }

    // MARK: - 恢复

    /// 从持久化存储恢复指定项目的标签页
    ///
    /// 使用两阶段恢复策略：
    /// 1. 批量创建 session（不加载文件内容），快速恢复标签栏 UI
    /// 2. 仅对上次活跃的标签页执行完整的 `openFile`（加载内容）
    func restoreTabs(
        forProject projectPath: String,
        openFile: @MainActor (URL) async -> Void,
        openFileSessionOnly: @MainActor (URL) -> Void
    ) async {
        let (persistedTabs, activeTabPath) = store.loadTabs(forProject: projectPath)

        // 过滤掉不存在的文件
        let validURLs = persistedTabs.compactMap { tab -> URL? in
            guard let url = tab.fileURL,
                  FileManager.default.isReadableFile(atPath: url.path) else {
                return nil
            }
            return url
        }

        guard !validURLs.isEmpty else { return }

        // 阶段 1：批量创建 session（不加载文件内容），快速恢复标签栏 UI
        for url in validURLs {
            openFileSessionOnly(url)
        }

        // 阶段 2：仅对上次活跃的标签页执行完整的 openFile（加载内容）
        let targetURL: URL
        if let activePath = activeTabPath,
           let activateURL = validURLs.first(where: { $0.path == activePath }) {
            targetURL = activateURL
        } else {
            targetURL = validURLs[0]
        }
        await openFile(targetURL)
    }

    // MARK: - 私有方法

    /// 从 tabs 和 activeSessionID 中提取活跃标签的文件路径
    private func activeTabPath(
        from tabs: [EditorTab],
        activeSessionID: UUID?
    ) -> String? {
        guard let activeSessionID else { return nil }
        return tabs.first(where: { $0.sessionID == activeSessionID })?.fileURL?.path
    }
}
