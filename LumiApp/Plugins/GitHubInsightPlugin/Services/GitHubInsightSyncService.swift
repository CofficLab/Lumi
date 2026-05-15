import Foundation

actor GitHubInsightSyncService {
    static let shared = GitHubInsightSyncService()

    private let profiler = GitHubInsightProjectProfiler()
    private let discoverer = GitHubInsightDiscoverer()
    private let knowledgeBase = GitHubInsightKnowledgeBaseManager.shared

    private var syncingProjects = Set<String>()

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

    func cachedState(projectPath: String) async -> GitHubInsightSyncState {
        let count = await knowledgeBase.loadEntries(projectPath: projectPath).count
        return count > 0 ? .ready(count: count) : .idle
    }
}

extension Notification.Name {
    static let githubInsightDidSync = Notification.Name("GitHubInsightDidSync")
}
