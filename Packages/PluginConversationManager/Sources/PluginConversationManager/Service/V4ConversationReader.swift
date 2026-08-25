import Foundation
import os
import ProviderConversation
import KitSuperLog
import SwiftData

/// v4 历史会话读取器（只读）
///
/// v2 的 `LegacyDataProviding` 被精简为纯目录探测（无 `fetchLegacyConversations`），
/// 故本插件自建读取器：定位 v4 数据根目录后，复制 `Core/Lumi.db`（+ -shm/-wal）
/// 到临时副本再只读打开 —— 既防锁竞争，又保住 WAL 数据，且绝不损坏原件。
///
/// 设计要点（沿袭旧版 `LegacyDataService`）：
/// - **单点打开**：复制副本 + 打开一次，后续 fetch 复用同一快照。
/// - **allowsSave: true**：SwiftData 打开库时会做 store 元数据校验/轻量迁移；
///   只读打开会因「Cannot migrate store in-place」失败。操作的是临时副本，安全。
/// - **吞错**：fetch 失败返回空数组并记日志，绝不向上抛（避免阻塞 onBoot）。
@MainActor
public final class V4ConversationReader: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "conversation.v4-reader")
    nonisolated public static let emoji = "🗂️"
    nonisolated static let verbose = false

    /// v4 数据根目录（原件）；nil 表示未找到旧数据（全新安装）。
    private let sourceRootDirectory: URL?

    /// v4 数据库文件名（与 v4 Configuration.databaseFileName 一致）
    private static let v4DatabaseFileName = "Lumi.db"

    /// 已建立的只读快照（nil 表示尚未打开）
    private var snapshot: Snapshot?

    private struct Snapshot {
        let copyDirectory: URL
        let container: ModelContainer
    }

    // MARK: - Initialization

    /// - Parameter v4DataRootDirectory: v4 数据根目录。传 nil 表示未找到旧数据。
    public init(v4DataRootDirectory: URL?) {
        self.sourceRootDirectory = v4DataRootDirectory
    }

    // MARK: - API

    /// 是否存在可迁移的 v4 旧数据（轻量探测，不打开数据库）。
    public func hasLegacyData() -> Bool {
        guard let root = sourceRootDirectory else { return false }
        let dbURL = root
            .appendingPathComponent("Core", isDirectory: true)
            .appendingPathComponent(Self.v4DatabaseFileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: dbURL.path)
    }

    /// 读取 v4 全部历史会话（转换成与存储无关的 `LumiConversationSummary`）。
    ///
    /// - Returns: 读取失败时返回空数组（吞错，不向上抛）。
    public func fetchLegacyConversations() -> [LumiConversationSummary] {
        guard let container = try? ensureSnapshot() else {
            Self.logger.error("\(Self.t)建立 v4 只读快照失败，跳过会话迁移")
            return []
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let entities = try context.fetch(descriptor)
            return entities.map { Self.convert($0) }
        } catch {
            Self.logger.error("\(Self.t)读取 v4 历史会话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 释放只读快照资源（幂等）。
    public func releaseLegacySnapshot() {
        snapshot = nil
    }

    // MARK: - Snapshot Management

    /// 确保只读快照已建立，返回容器。惰性打开、复用。
    private func ensureSnapshot() throws -> ModelContainer {
        if let snapshot { return snapshot.container }

        guard let root = sourceRootDirectory else {
            throw V4ConversationReaderError.legacyDataNotFound
        }

        let originalDB = root
            .appendingPathComponent("Core", isDirectory: true)
            .appendingPathComponent(Self.v4DatabaseFileName, isDirectory: false)

        guard FileManager.default.fileExists(atPath: originalDB.path) else {
            throw V4ConversationReaderError.legacyDataNotFound
        }

        // 1. 复制 .db / -shm / -wal 三件套到临时副本（同卷，保 WAL 数据 + 防锁）
        let copyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi_v4_conversation_migration_\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: copyDir, withIntermediateDirectories: true)
            for suffix in ["", "-shm", "-wal"] {
                let srcURL = URL(fileURLWithPath: originalDB.path + suffix)
                guard FileManager.default.fileExists(atPath: srcURL.path) else { continue }
                let dstURL = copyDir.appendingPathComponent(
                    Self.v4DatabaseFileName + suffix, isDirectory: false
                )
                try FileManager.default.copyItem(at: srcURL, to: dstURL)
            }
        } catch {
            throw V4ConversationReaderError.snapshotCopyFailed(underlying: error)
        }

        let copiedDB = copyDir.appendingPathComponent(Self.v4DatabaseFileName, isDirectory: false)

        // 2. 用 v4 legacy schema 打开副本。
        // 关键：allowsSave: true（不是 false）。SwiftData 打开库时会做 store 元数据
        // 校验/轻量迁移；若设只读，迁移无法写入会直接失败。由于操作的是临时副本，
        // 让 SwiftData 在副本上完成必要迁移是安全的，我们只 fetch 不 save。
        let schema = Schema([Conversation.self])
        let config = ModelConfiguration(
            schema: schema,
            url: copiedDB,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            snapshot = Snapshot(copyDirectory: copyDir, container: container)
            if Self.verbose {
                Self.logger.info("\(Self.t)已建立 v4 只读快照：\(copiedDB.path)")
            }
            return container
        } catch {
            throw V4ConversationReaderError.openFailed(underlying: error)
        }
    }

    // MARK: - Conversion (v4 entity → kernel DTO)

    /// v4 Conversation → LumiConversationSummary
    /// v4 的 model/projid 字段语义与 v5 略有差异，这里做字段映射。
    private static func convert(_ entity: Conversation) -> LumiConversationSummary {
        LumiConversationSummary(
            id: entity.id,
            title: entity.title,
            preview: entity.preview,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            verbosity: entity.verbosity.flatMap { LumiResponseVerbosity(rawValue: $0) },
            language: entity.languagePreference.flatMap { LumiConversationLanguage(rawValue: $0) },
            // v4 的 chatMode 即 v5 的 automationLevel（均为 a1/a2/a3 编码）
            automationLevel: entity.chatMode.flatMap { LumiAutomationLevel(rawValue: $0) },
            providerID: entity.providerId,
            modelName: entity.model,
            // v4 用 projectId（字符串），v5 用 projectPath。语义相近，原样迁移。
            projectPath: entity.projectId
        )
    }
}

// MARK: - Errors

enum V4ConversationReaderError: Error {
    case legacyDataNotFound
    case snapshotCopyFailed(underlying: Error)
    case openFailed(underlying: Error)
}

// MARK: - v4 数据根目录定位

/// 定位 v4 数据根目录（当前 v5 dataRoot 的兄弟目录）。
///
/// 与 `ProjectsLegacyMigration` 的定位逻辑一致：
/// v4 目录名 `db_production_v4`（Debug 另试 `db_debug_v4`）。
enum V4DataDirectoryLocator {
    /// - Parameter currentDataRootDirectory: v5 的 `StorageProviding.dataRootDirectory`。
    static func locate(currentDataRootDirectory: URL) -> URL? {
        let parent = currentDataRootDirectory.deletingLastPathComponent()
        let fileManager = FileManager.default

        #if DEBUG
        let candidates = ["db_production_v4", "db_debug_v4"]
        #else
        let candidates = ["db_production_v4"]
        #endif

        for name in candidates {
            let dir = parent.appendingPathComponent(name, isDirectory: true)
            if fileManager.fileExists(atPath: dir.path) {
                return dir
            }
        }
        return nil
    }
}
