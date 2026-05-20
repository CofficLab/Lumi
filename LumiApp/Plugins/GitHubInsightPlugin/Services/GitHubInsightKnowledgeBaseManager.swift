import Foundation

/// Manages persisted GitHub ecosystem knowledge base files for local projects.
///
/// Each project is stored as a JSON file named by a stable hash of its project path.
/// The manager provides isolated reads, writes, and refresh checks for those stores.
actor GitHubInsightKnowledgeBaseManager {
    /// Shared knowledge base manager used by the plugin.
    static let shared = GitHubInsightKnowledgeBaseManager()

    /// File system helper used for cache directory and file operations.
    private let fileManager = FileManager.default

    /// Root directory containing all project cache JSON files.
    private let rootDirectory: URL

    /// JSON decoder used for persisted project stores.
    private let decoder = JSONDecoder()

    /// JSON encoder used for persisted project stores.
    private let encoder = JSONEncoder()

    private init() {
        self.rootDirectory = AppConfig.getDBFolderURL()
            .appendingPathComponent("GitHubInsightPlugin", isDirectory: true)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    /// Loads the full persisted store for a project path.
    func loadStore(projectPath: String) -> GitHubInsightProjectStore? {
        let url = storeURL(for: projectPath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(GitHubInsightProjectStore.self, from: data)
    }

    /// Loads only the cached entries for a project path.
    func loadEntries(projectPath: String) -> [GitHubInsightKBEntry] {
        loadStore(projectPath: projectPath)?.entries ?? []
    }

    /// Loads cached entries across all project stores.
    func loadAllEntries() -> [GitHubInsightKBEntry] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return urls
            .filter { $0.pathExtension == "json" }
            .flatMap { url -> [GitHubInsightKBEntry] in
                guard let data = try? Data(contentsOf: url),
                      let store = try? decoder.decode(GitHubInsightProjectStore.self, from: data) else {
                    return []
                }
                return store.entries
            }
    }

    /// Persists a project's profile and discovered GitHub ecosystem entries.
    func save(projectPath: String, profile: GitHubInsightProjectProfile, entries: [GitHubInsightKBEntry]) throws {
        let store = GitHubInsightProjectStore(
            projectPath: projectPath,
            profile: profile,
            entries: entries,
            syncedAt: Date()
        )
        let data = try encoder.encode(store)
        let url = storeURL(for: projectPath)
        let temp = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".tmp")
        try data.write(to: temp, options: .atomic)
        if fileManager.fileExists(atPath: url.path) {
            _ = try fileManager.replaceItemAt(url, withItemAt: temp)
        } else {
            try fileManager.moveItem(at: temp, to: url)
        }
    }

    /// Returns whether the project cache is missing or older than the allowed age.
    func shouldRefresh(projectPath: String, maxAge: TimeInterval = 24 * 60 * 60) -> Bool {
        guard let store = loadStore(projectPath: projectPath) else { return true }
        return Date().timeIntervalSince(store.syncedAt) > maxAge
    }

    /// Builds the JSON file URL for a project path.
    private func storeURL(for projectPath: String) -> URL {
        rootDirectory.appendingPathComponent(stableHash(projectPath) + ".json")
    }

    /// Computes a stable FNV-1a hash for cache file naming.
    private func stableHash(_ input: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "%016llx", hash)
    }
}
