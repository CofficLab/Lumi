import Foundation

/// Coordinates profiling, GitHub discovery, and local cache persistence for a project.
///
/// This actor serializes sync work per project path so repeated UI lifecycle events
/// do not launch duplicate GitHub discovery tasks for the same project.
actor GitHubInsightSyncService {
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
            return .syncing
        }

        let needsRefresh = await knowledgeBase.shouldRefresh(projectPath: normalizedPath)
        if !force, !needsRefresh {
            let count = await knowledgeBase.loadEntries(projectPath: normalizedPath).count
            return .ready(count: count)
        }

        syncingProjects.insert(normalizedPath)
        defer { syncingProjects.remove(normalizedPath) }

        do {
            guard let profile = profiler.profile(projectPath: normalizedPath) else {
                return .failed("Project path is not readable.")
            }
            let entries = try await discoverer.discover(profile: profile)
            try await knowledgeBase.save(projectPath: normalizedPath, profile: profile, entries: entries)
            await MainActor.run {
                NotificationCenter.default.post(name: .githubInsightDidSync, object: nil, userInfo: ["projectPath": normalizedPath])
            }
            return .ready(count: entries.count)
        } catch {
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
