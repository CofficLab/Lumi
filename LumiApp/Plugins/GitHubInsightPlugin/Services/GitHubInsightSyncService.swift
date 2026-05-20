import Foundation
import MagicKit

/// Coordinates profiling, GitHub discovery, and local cache persistence for a project.
///
/// This actor serializes sync work per project path so repeated UI lifecycle events
/// do not launch duplicate GitHub discovery tasks for the same project.
actor GitHubInsightSyncService: SuperLog {
    /// Shared sync coordinator used by the status bar view model.
    static let shared = GitHubInsightSyncService()

    /// Project profiler used to infer frameworks, dependencies, and keywords.
    private let profiler = GitHubInsightProjectProfiler()

    /// GitHub repository discoverer used to search ecosystem references.
    private let discoverer = GitHubInsightDiscoverer()

    /// Local knowledge base manager used for cache reads and writes.
    private let knowledgeBase = GitHubInsightKnowledgeBaseManager.shared

    /// Normalized project paths that are currently being synchronized.
    private var syncingProjects = Set<String>()

    /// Synchronizes a project's GitHub ecosystem cache when missing, stale, or forced.
    ///
    /// - Parameters:
    ///   - projectPath: Local project root path.
    ///   - force: Whether to refresh even when the cache is still fresh.
    /// - Returns: The resulting sync state for the project.
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

    /// Returns the current cache state without triggering network discovery.
    func cachedState(projectPath: String) async -> GitHubInsightSyncState {
        let count = await knowledgeBase.loadEntries(projectPath: projectPath).count
        return count > 0 ? .ready(count: count) : .idle
    }
}

/// Notifications emitted by the GitHub insight sync workflow.
extension Notification.Name {
    /// Posted after a project's GitHub ecosystem cache has been successfully synced.
    static let githubInsightDidSync = Notification.Name("GitHubInsightDidSync")
}
