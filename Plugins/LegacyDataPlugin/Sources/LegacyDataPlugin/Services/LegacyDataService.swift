import Foundation
import LumiKernel
import SwiftData
import SuperLogKit
import os

/// v4 旧数据读取服务(只读)
///
/// 实现 `LegacyDataProviding`,负责:
/// 1. 定位 v4 数据根目录(`db_production_v4`,与当前版本目录同级)。
/// 2. 复制 `Lumi.db` + `-shm` + `-wal` 三件套到临时副本后只读打开 —— 既防多插件
///    各开同一文件造成锁竞争,又保住 WAL 里未 checkpoint 的数据,且绝不损坏原件。
/// 3. 用 v4 legacy @Model 定义查询,转换成与存储无关的内核 DTO
///    (`LumiConversationSummary` / `LumiChatMessage`)返回。
///
/// # 生命周期
/// - 首次 fetch 时惰性打开副本;后续调用复用同一快照。
/// - 所有消费插件完成迁移后,由调用方调 `releaseLegacySnapshot()` 释放(关闭 context,
///   可选删除临时副本)。幂等。
@MainActor
public final class LegacyDataService: LegacyDataProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.legacy-data")
    nonisolated public static let emoji = "🗂️"
    nonisolated static let verbose = true

    /// v4 数据根目录(原件)
    private let sourceRootDirectory: URL?

    /// v4 数据库文件名(与 v4 Configuration.databaseFileName 一致)
    private static let v4DatabaseFileName = "Lumi.db"

    /// 已建立的只读快照(nil 表示尚未打开)
    private var snapshot: Snapshot?

    private struct Snapshot {
        let copyDirectory: URL
        let container: ModelContainer
    }

    // MARK: - Initialization

    /// - Parameter v4DataRootDirectory: v4 数据根目录。传 nil 表示未找到旧数据
    ///   (全新安装)。由 `LegacyDataPlugin` 在 onBoot 时定位后注入。
    public init(v4DataRootDirectory: URL?) {
        self.sourceRootDirectory = v4DataRootDirectory
    }

    // MARK: - LegacyDataProviding

    public var legacyDataRootDirectory: URL? { sourceRootDirectory }

    public func hasLegacyData() -> Bool {
        guard let root = sourceRootDirectory else { return false }
        let dbURL = root
            .appendingPathComponent("Core", isDirectory: true)
            .appendingPathComponent(Self.v4DatabaseFileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: dbURL.path)
    }

    public func fetchLegacyConversations() throws -> [LumiConversationSummary] {
        let container = try ensureSnapshot()

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LegacyV4Conversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let entities: [LegacyV4Conversation]
        do {
            entities = try context.fetch(descriptor)
        } catch {
            throw LegacyDataError.fetchFailed(entity: "Conversation", underlying: error)
        }

        return entities.map { Self.convert($0) }
    }

    public func fetchLegacyMessages(for conversationID: UUID) throws -> [LumiChatMessage] {
        let container = try ensureSnapshot()

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LegacyV4ChatMessageEntity>(
            predicate: #Predicate { $0.conversationId == conversationID },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        let entities: [LegacyV4ChatMessageEntity]
        do {
            entities = try context.fetch(descriptor)
        } catch {
            throw LegacyDataError.fetchFailed(entity: "ChatMessageEntity", underlying: error)
        }

        return entities.compactMap { Self.convert($0) }
    }

    public func releaseLegacySnapshot() {
        // ModelContext 在 deinit 会自动关闭;这里只释放强引用即可。
        // 临时副本保留在临时目录,由系统按策略清理(便于失败后排查)。
        snapshot = nil
        if Self.verbose {
            Self.logger.info("\(Self.t)已释放 v4 只读快照")
        }
    }

    // MARK: - Snapshot Management

    /// 确保只读快照已建立,返回容器。惰性打开、复用。
    private func ensureSnapshot() throws -> ModelContainer {
        if let snapshot { return snapshot.container }

        guard let root = sourceRootDirectory else {
            throw LegacyDataError.legacyDataNotFound
        }

        let originalDB = root
            .appendingPathComponent("Core", isDirectory: true)
            .appendingPathComponent(Self.v4DatabaseFileName, isDirectory: false)

        guard FileManager.default.fileExists(atPath: originalDB.path) else {
            throw LegacyDataError.legacyDataNotFound
        }

        // 1. 复制 .db / -shm / -wal 三件套到临时副本(同卷,保 WAL 数据 + 防锁)
        let copyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi_v4_migration_\(UUID().uuidString)", isDirectory: true)
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
            throw LegacyDataError.snapshotCopyFailed(underlying: error)
        }

        let copiedDB = copyDir.appendingPathComponent(Self.v4DatabaseFileName, isDirectory: false)

        // 2. 用 v4 legacy schema 只读打开副本(allowsSave: false 防止任何写入/迁移)
        let schema = Schema([
            LegacyV4Conversation.self,
            LegacyV4ChatMessageEntity.self,
            LegacyV4ImageAttachmentEntity.self,
            LegacyV4ToolCallEntity.self,
            LegacyV4MessageMetricsEntity.self,
            LegacyV4ChatStateEntity.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: copiedDB,
            allowsSave: false,
            cloudKitDatabase: .none
        )

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw LegacyDataError.openFailed(underlying: error)
        }

        snapshot = Snapshot(copyDirectory: copyDir, container: container)
        if Self.verbose {
            Self.logger.info("\(Self.t)已建立 v4 只读快照: \(copiedDB.path)")
        }
        return container
    }

    // MARK: - Conversion (v4 entity → kernel DTO)

    /// v4 Conversation → LumiConversationSummary
    /// v4 的 model/projid 字段语义与 v5 略有差异,这里做字段映射。
    private static func convert(_ entity: LegacyV4Conversation) -> LumiConversationSummary {
        LumiConversationSummary(
            id: entity.id,
            title: entity.title,
            preview: entity.preview,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            verbosity: entity.verbosity.flatMap { LumiResponseVerbosity(rawValue: $0) },
            language: entity.languagePreference.flatMap { LumiConversationLanguage(rawValue: $0) },
            // v4 的 chatMode 即 v5 的 automationLevel(均为 a1/a2/a3 编码)
            automationLevel: entity.chatMode.flatMap { LumiAutomationLevel(rawValue: $0) },
            providerID: entity.providerId,
            modelName: entity.model,
            // v4 用 projectId(字符串),v5 用 projectPath。语义相近,原样迁移。
            projectPath: entity.projectId
        )
    }

    /// v4 ChatMessageEntity → LumiChatMessage
    /// toolCalls / metrics 已内嵌在该实体的 JSON 字段里,无需额外查独立表。
    private static func convert(_ entity: LegacyV4ChatMessageEntity) -> LumiChatMessage? {
        guard let role = LumiChatMessageRole(rawValue: entity.role) else { return nil }

        let decoder = JSONDecoder()
        let metadata: [String: String] = (entity.metadataJSON ?? "").isEmpty
            ? [:]
            : ((try? decoder.decode([String: String].self, from: Data(entity.metadataJSON!.utf8))) ?? [:])
        let toolCalls: [LumiToolCall]? = entity.toolCallsJSON.flatMap {
            try? decoder.decode([LumiToolCall].self, from: Data($0.utf8))
        }

        return LumiChatMessage(
            id: entity.id,
            conversationID: entity.conversationId,
            role: role,
            content: entity.content,
            createdAt: entity.timestamp,
            providerID: entity.providerId,
            modelName: entity.modelName,
            isError: entity.isError,
            rawErrorDetail: entity.rawErrorDetail,
            renderKind: entity.renderKind,
            metadata: metadata,
            toolCalls: toolCalls,
            toolCallID: entity.toolCallID,
            reasoningContent: entity.reasoningContent
            // v4 的 ChatMessageEntity 不含 token 统计字段(在独立的 MessageMetricsEntity 表)。
            // 本次迁移不合并 metrics(该表实测多为空),故这几项留 nil:
            // inputTokenCount / outputTokenCount / latencyMs / timeToFirstTokenMs / streamingDurationMs
        )
    }
}
