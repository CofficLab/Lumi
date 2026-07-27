import Foundation
import LumiKernel
import os
import SuperLogKit

/// 管理本地项目持久化的 GitHub 生态知识库文件。
///
/// 每个项目都会保存为一个 JSON 文件，文件名由项目路径的稳定哈希生成。
/// 管理器为这些存储提供隔离的读取、写入和刷新检查能力。
public actor GitHubInsightKnowledgeBaseManager: SuperLog {
    /// 插件使用的共享知识库管理器。
    public static let shared = GitHubInsightKnowledgeBaseManager()
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-insight.knowledge-base")

    /// 用于缓存目录和文件操作的文件系统工具。
    private let fileManager = FileManager.default

    /// 存放所有项目缓存 JSON 文件的根目录。
    private let rootDirectory: URL

    /// 用于持久化项目存储的 JSON 解码器。
    private let decoder = JSONDecoder()

    /// 用于持久化项目存储的 JSON 编码器。
    private let encoder = JSONEncoder()

    public init() {
        let defaultRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitHubInsightPlugin", isDirectory: true)
        self.init(rootDirectory: GitHubInsightRuntimeBridge.rootDirectory ?? defaultRoot)
    }

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(Self.t)Create GitHub insight store directory failed: \(error.localizedDescription)")
        }
    }

    /// 加载某个项目路径对应的完整持久化存储。
    public func loadStore(projectPath: String) -> GitHubInsightProjectStore? {
        let url = storeURL(for: projectPath)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(GitHubInsightProjectStore.self, from: data)
        } catch {
            Self.logger.error("\(Self.t)Load GitHub insight store failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// 仅加载某个项目路径对应的缓存条目。
    public func loadEntries(projectPath: String) -> [GitHubInsightKBEntry] {
        loadStore(projectPath: projectPath)?.entries ?? []
    }

    /// 加载所有项目存储中的缓存条目。
    public func loadAllEntries() -> [GitHubInsightKBEntry] {
        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: rootDirectory,
                includingPropertiesForKeys: nil
            )
        } catch {
            Self.logger.error("\(Self.t)List GitHub insight stores failed: \(error.localizedDescription)")
            return []
        }

        return urls
            .filter { $0.pathExtension == "json" }
            .flatMap { url -> [GitHubInsightKBEntry] in
                do {
                    let data = try Data(contentsOf: url)
                    let store = try decoder.decode(GitHubInsightProjectStore.self, from: data)
                    return store.entries
                } catch {
                    Self.logger.error("\(Self.t)Load GitHub insight store from list failed: \(error.localizedDescription)")
                    return []
                }
            }
    }

    /// 持久化项目画像和发现到的 GitHub 生态条目。
    public func save(projectPath: String, profile: GitHubInsightProjectProfile, entries: [GitHubInsightKBEntry]) throws {
        let store = GitHubInsightProjectStore(
            projectPath: projectPath,
            profile: profile,
            entries: entries,
            syncedAt: Date()
        )
        let data = try encoder.encode(store)
        let url = storeURL(for: projectPath)
        let temp = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".tmp")
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            try data.write(to: temp, options: .atomic)
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: temp)
            } else {
                try fileManager.moveItem(at: temp, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: temp)
            Self.logger.error("\(Self.t)Persist GitHub insight store failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// 判断项目缓存是否缺失或超过允许的最大年龄。
    public func shouldRefresh(projectPath: String, maxAge: TimeInterval = 24 * 60 * 60) -> Bool {
        guard let store = loadStore(projectPath: projectPath) else { return true }
        return Date().timeIntervalSince(store.syncedAt) > maxAge
    }

    /// 为项目路径构建对应的 JSON 文件 URL。
    private func storeURL(for projectPath: String) -> URL {
        rootDirectory.appendingPathComponent(stableHash(projectPath) + ".json")
    }

    /// 计算用于缓存文件命名的稳定 FNV-1a 哈希。
    private func stableHash(_ input: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "%016llx", hash)
    }
}
