import Combine
import Foundation
import MagicKit
import os

/// 编辑器标签页持久化协调器
///
/// 订阅 `EditorSessionStore` 的 tabs 变化，自动防抖保存到磁盘；
/// 在项目路径变化时保存旧项目标签并恢复新项目标签。
///
/// 通过 `@EnvironmentObject` 获取 `EditorVM` 和 `ProjectVM`，
/// 不依赖任何其他插件。
@MainActor
final class EditorTabStripCoordinator: ObservableObject, SuperLog {
    nonisolated static var emoji: String { "📑" }
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-tab-strip")

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
        openFile: @MainActor @escaping (URL) -> Void
    ) {
        trackedProjectPath = projectPathProvider()

        // 🔍 诊断日志
        Self.logger.info("[TabRestore-DIAG] startObserving 被调用: hasRestored=\(self.hasRestored), tabs.count=\(sessionStore.tabs.count), projectPath=\(self.trackedProjectPath, privacy: .public)")

        // 首次启动且 tabs 为空 → 从磁盘恢复
        if !hasRestored && sessionStore.tabs.isEmpty {
            Self.logger.info("[TabRestore-DIAG] ✅ 满足恢复条件，开始 restoreTabs")
            hasRestored = true
            restoreTabs(forProject: trackedProjectPath, openFile: openFile)
        } else {
            // 🔍 诊断日志：为什么不恢复
            if hasRestored {
                Self.logger.info("[TabRestore-DIAG] ❌ 跳过恢复：hasRestored 已经为 true")
            } else if !sessionStore.tabs.isEmpty {
                Self.logger.info("[TabRestore-DIAG] ❌ 跳过恢复：tabs 不为空（count=\(sessionStore.tabs.count)），说明已有其他地方打开了文件")
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

        if Self.verbose {
            Self.logger.info("\(Self.t)开始订阅 tabs 变化, projectPath=\(self.trackedProjectPath, privacy: .public)")
        }
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

        if Self.verbose {
            Self.logger.info("\(Self.t)停止订阅，已保存 tabs, projectPath=\(projectPath, privacy: .public)")
        }
    }

    // MARK: - 项目切换

    /// 处理项目路径变化：保存旧项目 → 恢复新项目
    func handleProjectPathChange(
        oldPath: String,
        newPath: String,
        sessionStore: EditorSessionStore,
        openFile: @MainActor (URL) -> Void
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
        restoreTabs(forProject: newPath, openFile: openFile)
    }

    // MARK: - 恢复

    /// 从持久化存储恢复指定项目的标签页
    func restoreTabs(
        forProject projectPath: String,
        openFile: @MainActor (URL) -> Void
    ) {
        let (persistedTabs, activeTabPath) = store.loadTabs(forProject: projectPath)

        Self.logger.info("\(Self.t)恢复标签页, projectPath=\(projectPath, privacy: .public), persistedCount=\(persistedTabs.count), activeTabPath=\(activeTabPath ?? "nil", privacy: .public)")

        // 过滤掉不存在的文件
        let validURLs = persistedTabs.compactMap { tab -> URL? in
            guard let url = tab.fileURL,
                  FileManager.default.isReadableFile(atPath: url.path) else {
                Self.logger.warning("\(Self.t)跳过不可读文件: \(tab.path, privacy: .public)")
                return nil
            }
            return url
        }

        Self.logger.info("\(Self.t)有效标签页数=\(validURLs.count)")
        guard !validURLs.isEmpty else { return }

        // 打开所有标签页
        for url in validURLs {
            openFile(url)
        }

        // 最后激活上次保存的活跃标签
        if let activePath = activeTabPath,
           let activateURL = validURLs.first(where: { $0.path == activePath }) {
            Self.logger.info("\(Self.t)激活活跃标签: \(activateURL.path, privacy: .public)")
            openFile(activateURL)
        }
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
