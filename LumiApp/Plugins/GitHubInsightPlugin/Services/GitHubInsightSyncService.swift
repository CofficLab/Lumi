import Foundation

/// 协调项目画像、GitHub 发现和本地缓存持久化。
///
/// 该 actor 按项目路径串行化同步工作，避免重复的 UI 生命周期事件为同一项目
/// 启动重复的 GitHub 发现任务。
actor GitHubInsightSyncService: SuperLog {
    /// 状态栏视图模型使用的共享同步协调器。
    static let shared = GitHubInsightSyncService()

    /// 用于推断框架、依赖和关键词的项目画像器。
    private let profiler = GitHubInsightProjectProfiler()

    /// 用于搜索生态参考的 GitHub 仓库发现器。
    private let discoverer = GitHubInsightDiscoverer()

    /// 用于缓存读写的本地知识库管理器。
    private let knowledgeBase = GitHubInsightKnowledgeBaseManager.shared

    /// 当前正在同步的标准化项目路径。
    private var syncingProjects = Set<String>()

    /// 在项目 GitHub 生态缓存缺失、过期或被强制刷新时执行同步。
    ///
    /// - Parameters:
    ///   - projectPath: 本地项目根目录路径。
    ///   - force: 是否在缓存仍然新鲜时也强制刷新。
    /// - Returns: 项目同步后的状态。
    func syncIfNeeded(projectPath: String, force: Bool = false) async -> GitHubInsightSyncState {
        let normalizedPath = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        guard !normalizedPath.isEmpty else { return .idle }

        if syncingProjects.contains(normalizedPath) {
            GitHubInsightPlugin.logger.info("\(Self.t)同步已在进行中，跳过重复任务：\(normalizedPath)")
            return .syncing
        }

        let needsRefresh = await knowledgeBase.shouldRefresh(projectPath: normalizedPath)
        if !force, !needsRefresh {
            let count = await knowledgeBase.loadEntries(projectPath: normalizedPath).count
            GitHubInsightPlugin.logger.info("\(Self.t)缓存未过期，跳过 GitHub 发现：\(normalizedPath)，现有条目：\(count)")
            return .ready(count: count)
        }

        syncingProjects.insert(normalizedPath)
        defer { syncingProjects.remove(normalizedPath) }

        do {
            GitHubInsightPlugin.logger.info("\(Self.t)开始同步 GitHub 生态知识库：\(normalizedPath)，force=\(force)")
            guard let profile = profiler.profile(projectPath: normalizedPath) else {
                GitHubInsightPlugin.logger.error("\(Self.t)项目路径不可读，无法同步 GitHub 生态知识库：\(normalizedPath)")
                return .failed("Project path is not readable.")
            }
            GitHubInsightPlugin.logger.info("\(Self.t)项目画像完成：language=\(profile.primaryLanguage ?? "Unknown")，frameworks=\(profile.frameworks.count)，dependencies=\(profile.dependencies.count)，keywords=\(profile.keywords.count)")

            let entries = try await discoverer.discover(profile: profile)
            try await knowledgeBase.save(projectPath: normalizedPath, profile: profile, entries: entries)
            GitHubInsightPlugin.logger.info("\(Self.t)GitHub 生态知识库同步完成：\(normalizedPath)，缓存条目：\(entries.count)")
            await MainActor.run {
                NotificationCenter.default.post(name: .githubInsightDidSync, object: nil, userInfo: ["projectPath": normalizedPath])
            }
            return .ready(count: entries.count)
        } catch {
            GitHubInsightPlugin.logger.error("\(Self.t)GitHub 生态知识库同步失败：\(normalizedPath)，错误：\(error.localizedDescription)")
            if error.localizedDescription.localizedCaseInsensitiveContains("rate") {
                return .rateLimited
            }
            return .failed(error.localizedDescription)
        }
    }

    /// 返回当前缓存状态，不触发网络发现。
    func cachedState(projectPath: String) async -> GitHubInsightSyncState {
        let count = await knowledgeBase.loadEntries(projectPath: projectPath).count
        return count > 0 ? .ready(count: count) : .idle
    }
}

/// GitHub 生态洞察同步流程发出的通知。
extension Notification.Name {
    /// 在项目 GitHub 生态缓存成功同步后发出。
    static let githubInsightDidSync = Notification.Name("GitHubInsightDidSync")
}
