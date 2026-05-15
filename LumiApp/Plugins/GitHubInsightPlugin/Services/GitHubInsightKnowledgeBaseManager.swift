import Foundation

actor GitHubInsightKnowledgeBaseManager {
    static let shared = GitHubInsightKnowledgeBaseManager()

    private let fileManager = FileManager.default
    private let rootDirectory: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        self.rootDirectory = AppConfig.getDBFolderURL()
            .appendingPathComponent("GitHubInsightPlugin", isDirectory: true)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    func loadStore(projectPath: String) -> GitHubInsightProjectStore? {
        let url = storeURL(for: projectPath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(GitHubInsightProjectStore.self, from: data)
    }

    func loadEntries(projectPath: String) -> [GitHubInsightKBEntry] {
        loadStore(projectPath: projectPath)?.entries ?? []
    }

    func loadAllEntries() -> [GitHubInsightKBEntry] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return urls
            .filter { $0.pathExtension == "json" }
            .flatMap { url in
                guard let data = try? Data(contentsOf: url),
                      let store = try? decoder.decode(GitHubInsightProjectStore.self, from: data) else {
                    return []
                }
                return store.entries
            }
    }

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

    func shouldRefresh(projectPath: String, maxAge: TimeInterval = 24 * 60 * 60) -> Bool {
        guard let store = loadStore(projectPath: projectPath) else { return true }
        return Date().timeIntervalSince(store.syncedAt) > maxAge
    }

    private func storeURL(for projectPath: String) -> URL {
        rootDirectory.appendingPathComponent(stableHash(projectPath) + ".json")
    }

    private func stableHash(_ input: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "%016llx", hash)
    }
}
