import Combine
import LumiKernel
import SuperLogKit
import Foundation

/// 编辑器标签页持久化协调器
///
/// 订阅 `EditorTabStripCoordination.tabStripStatePublisher` 的标签变化,自动防抖保存到磁盘;
/// 在项目路径变化时保存旧项目标签并恢复新项目标签。
///
/// 通过协议消费编辑器能力,不直接依赖 `EditorService`。
@MainActor
public final class StripCoordinator: ObservableObject, SuperLog {
    public nonisolated static var emoji: String { "📑" }

    // MARK: - 属性

    private let store: StripStore
    private var cancellables = Set<AnyCancellable>()

    init(store: StripStore = .shared) {
        self.store = store
    }

    /// 是否已完成首次恢复（避免 onAppear 与 onChange 重复恢复）
    private var hasRestored = false

    /// 当前跟踪的项目路径
    private var trackedProjectPath: String = ""
    private var restoreToken = UUID()

    // MARK: - 订阅

    /// 开始订阅 tabs 变化，自动防抖保存；如果是首次调用且 tabs 为空，立即恢复。
    public func startObserving(
        coordination: any EditorTabStripCoordination,
        projectPathProvider: @MainActor @escaping () -> String,
        openFile: @MainActor @escaping (URL) async -> Void,
        openFileSessionOnly: @MainActor @escaping (URL) -> Void
    ) {
        trackedProjectPath = projectPathProvider()
        restoreToken = UUID()

        // 首次启动且 tabs 为空 → 等待项目路径就绪后从磁盘恢复
        if !hasRestored, coordination.currentTabs.isEmpty {
            Task { @MainActor [weak self] in
                await self?.attemptInitialRestore(
                    coordination: coordination,
                    projectPathProvider: projectPathProvider,
                    openFile: openFile,
                    openFileSessionOnly: openFileSessionOnly
                )
            }
        }

        coordination.tabStripStatePublisher
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                let path = projectPathProvider()
                guard !path.isEmpty else { return }
                let activeTabPath = self.activeTabPath(
                    from: state.tabs, activeSessionID: state.activeSessionID
                )
                self.store.saveTabs(
                    projectPath: path,
                    tabs: state.tabs,
                    activeTabPath: activeTabPath
                )
            }
            .store(in: &cancellables)
    }

    /// 停止订阅并立即保存当前状态
    public func stopObserving(
        coordination: any EditorTabStripCoordination,
        projectPath: String
    ) {
        cancellables.removeAll()

        guard !projectPath.isEmpty else { return }
        let activeTabPath = self.activeTabPath(
            from: coordination.currentTabs,
            activeSessionID: coordination.currentActiveSessionID
        )
        store.saveTabs(
            projectPath: projectPath,
            tabs: coordination.currentTabs,
            activeTabPath: activeTabPath
        )
    }

    // MARK: - 项目切换

    /// 处理项目路径变化：保存旧项目 → 恢复新项目
    public func handleProjectPathChange(
        oldPath: String,
        newPath: String,
        coordination: any EditorTabStripCoordination,
        openFile: @MainActor @escaping (URL) async -> Void,
        openFileSessionOnly: @MainActor @escaping (URL) -> Void
    ) {
        // 保存旧项目的标签页
        if !oldPath.isEmpty {
            let activeTabPath = self.activeTabPath(
                from: coordination.currentTabs,
                activeSessionID: coordination.currentActiveSessionID
            )
            store.saveTabs(
                projectPath: oldPath,
                tabs: coordination.currentTabs,
                activeTabPath: activeTabPath
            )
        }

        trackedProjectPath = newPath
        restoreToken = UUID()
        let currentToken = restoreToken

        // 恢复新项目的标签页
        guard !newPath.isEmpty else { return }
        Task { @MainActor [weak self] in
            await self?.restoreTabs(
                forProject: newPath,
                token: currentToken,
                openFile: openFile,
                openFileSessionOnly: openFileSessionOnly
            )
        }
    }

    // MARK: - 恢复

    /// 从持久化存储恢复指定项目的标签页
    ///
    /// 先加载上次活跃标签的内容，再为其余标签创建后台 session（不改变活跃标签）。
    public func restoreTabs(
        forProject projectPath: String,
        token: UUID? = nil,
        openFile: @MainActor (URL) async -> Void,
        openFileSessionOnly: @MainActor (URL) -> Void
    ) async {
        if let token, token != restoreToken { return }
        let (persistedTabs, activeTabPath) = store.loadTabs(forProject: projectPath)

        // 过滤掉不存在的文件
        let validURLs = persistedTabs.compactMap { tab -> URL? in
            guard let url = tab.fileURL,
                  FileManager.default.isReadableFile(atPath: url.path),
                  Self.isFile(url, inProjectPath: projectPath) else {
                return nil
            }
            return url
        }

        guard !validURLs.isEmpty else { return }

        let targetURL: URL
        if let activePath = activeTabPath,
           let activateURL = validURLs.first(where: { $0.path == activePath }) {
            targetURL = activateURL
        } else {
            targetURL = validURLs[0]
        }

        let backgroundURLs = validURLs.filter { $0.path != targetURL.path }
        for url in backgroundURLs {
            if let token, token != restoreToken { return }
            openFileSessionOnly(url)
        }
        if let token, token != restoreToken { return }
        await openFile(targetURL)
    }

    // MARK: - 私有方法

    /// 轮询等待项目路径就绪，避免空路径时过早消费首次恢复机会。
    private func attemptInitialRestore(
        coordination: any EditorTabStripCoordination,
        projectPathProvider: @MainActor @escaping () -> String,
        openFile: @MainActor @escaping (URL) async -> Void,
        openFileSessionOnly: @MainActor @escaping (URL) -> Void
    ) async {
        for _ in 0 ..< 60 {
            guard !hasRestored, coordination.currentTabs.isEmpty else { return }

            let path = projectPathProvider().trimmingCharacters(in: .whitespacesAndNewlines)
            if path.isEmpty {
                try? await Task.sleep(nanoseconds: 50_000_000)
                continue
            }

            hasRestored = true
            await restoreTabs(
                forProject: path,
                token: restoreToken,
                openFile: openFile,
                openFileSessionOnly: openFileSessionOnly
            )
            return
        }
    }

    /// 从 tabs 和 activeSessionID 中提取活跃标签的文件路径
    private func activeTabPath(
        from tabs: [TabDescriptor],
        activeSessionID: UUID?
    ) -> String? {
        guard let activeSessionID else { return nil }
        return tabs.first(where: { $0.sessionID == activeSessionID })?.fileURL?.path
    }

    nonisolated private static func isFile(_ url: URL, inProjectPath projectPath: String) -> Bool {
        let normalizedProject = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        let normalizedFile = url.standardizedFileURL.path
        return normalizedFile == normalizedProject || normalizedFile.hasPrefix(normalizedProject + "/")
    }
}
