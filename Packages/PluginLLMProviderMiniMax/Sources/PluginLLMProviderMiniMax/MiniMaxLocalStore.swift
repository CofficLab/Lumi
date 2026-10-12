import Foundation
import os
import KitLLM
import ProviderStorage
import LumiLoggingKit

/// MiniMax 插件本地存储。
///
/// 只负责一件事：持久化远程模型列表快照。
/// 存储位置：`kernel.storage.pluginDataDirectory(for: MiniMaxProviderPlugin.pluginID)/models.json`
///
/// 双层结构：
/// - 内存：本次会话内多次读取直接命中，避免重复 JSON 解析与磁盘 IO。
/// - 磁盘：JSON 文件，跨启动保留，远程拉取失败时兜底显示。
///
/// 约定：
/// - **失败 / 过期不删除旧值**。`isStale` 仅以 `syncedAt` 为准（超过 TTL 表示
///   "该重新拉取了"），但旧值仍可用，供离线 / 拉取失败时兜底。
/// - `store` 收到空列表时忽略写入，避免用空快照覆盖有效缓存。
/// - 未 `configure` 时降级为纯内存，不静默回落到其他位置。
final class MiniMaxLocalStore: SuperLog, @unchecked Sendable {
    private struct Snapshot: Codable {
        var models: [CachedModel]
        var syncedAt: Date
    }

    private struct CachedModel: Codable {
        let id: String
        let displayName: String?
        let contextWindowSize: Int?
    }

    /// 数据新鲜度阈值（TTL），默认 24h。
    static let ttl: TimeInterval = 24 * 60 * 60

    nonisolated private static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.minimax.local-store"
    )
    nonisolated static let emoji = "⚡"

    private static let fileName = "models.json"

    private let lock = NSLock()
    private var snapshotFileURL: URL?
    private var memory: Snapshot?

    // MARK: - 初始化

    /// 未绑定目录的纯内存实例（供测试与 storage 缺失时降级）。
    init() {}

    /// 绑定到指定目录的实例。
    ///
    /// - Parameter directory: 插件数据目录，通常来自 `pluginDataDirectory(for:)`。
    init(directory: URL) {
        snapshotFileURL = directory.appendingPathComponent(Self.fileName)
    }

    // MARK: - 配置

    /// 用内核存储能力完成懒绑定（`onBoot` 中调用一次）。
    @MainActor
    func configure(storage: (any StorageProviding)?) {
        guard let storage else {
            Self.logger.error("\(Self.t)storage is nil; model list cache stays in-memory only")
            return
        }
        let root = storage.pluginDataDirectory(for: MiniMaxProviderPlugin.pluginID)
        snapshotFileURL = root.appendingPathComponent(Self.fileName)
    }

    // MARK: - Public API

    /// 读取缓存快照；磁盘未命中或内容损坏时返回 `nil`。
    ///
    /// 返回的 `models` 为复制值，避免外部改动污染缓存。
    func cachedSnapshot() -> (models: [LLMModelInfo], syncedAt: Date, isStale: Bool)? {
        lock.lock(); defer { lock.unlock() }
        let snapshot: Snapshot
        if let memory {
            snapshot = memory
        } else if let disk = readDisk() {
            snapshot = disk
            memory = disk
        } else {
            return nil
        }
        return (
            models: snapshot.models.map { LLMModelInfo(id: $0.id, displayName: $0.displayName, contextWindowSize: $0.contextWindowSize) },
            syncedAt: snapshot.syncedAt,
            isStale: Date().timeIntervalSince(snapshot.syncedAt) > Self.ttl
        )
    }

    /// 成功拉取后写入缓存（内存 + 磁盘）。`models` 为空时忽略写入。
    func store(models: [LLMModelInfo], syncedAt: Date = Date()) {
        guard !models.isEmpty else { return }
        let snapshot = Snapshot(
            models: models.map { CachedModel(id: $0.id, displayName: $0.displayName, contextWindowSize: $0.contextWindowSize) },
            syncedAt: syncedAt
        )
        lock.lock(); defer { lock.unlock() }
        memory = snapshot
        writeDisk(snapshot)
    }

    /// 清空缓存（内存 + 磁盘）。
    func clear() {
        lock.lock(); defer { lock.unlock() }
        memory = nil
        guard let snapshotFileURL else { return }
        try? FileManager.default.removeItem(at: snapshotFileURL)
    }

    // MARK: - Private

    private func readDisk() -> Snapshot? {
        guard let snapshotFileURL,
              let data = try? Data(contentsOf: snapshotFileURL) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            // 损坏内容不删除，下次成功写入时自然覆盖；此处仅记录，避免刷屏。
            Self.logger.warning("\(Self.t)decode model list cache failed; fall back to static catalog")
            return nil
        }
        return snapshot
    }

    /// 原子写入：先写临时文件，再替换目标，避免进程中断留下半截 JSON。
    private func writeDisk(_ snapshot: Snapshot) {
        guard let snapshotFileURL else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else {
            Self.logger.error("\(Self.t)encode model list cache failed")
            return
        }
        let directory = snapshotFileURL.deletingLastPathComponent()
        let temporaryURL = directory.appendingPathComponent("\(Self.fileName).tmp")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: temporaryURL, options: .atomic)
            if FileManager.default.fileExists(atPath: snapshotFileURL.path) {
                _ = try FileManager.default.replaceItemAt(snapshotFileURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: snapshotFileURL)
            }
        } catch {
            Self.logger.error("\(Self.t)persist model list cache failed: \(error.localizedDescription, privacy: .public)")
            try? FileManager.default.removeItem(at: temporaryURL)
        }
    }
}