import Foundation
import os
import ProviderMessage
import LumiLoggingKit
import SwiftData

/// v4 历史消息读取器（只读，#394）
///
/// 与 `V4ConversationReader` 同构：定位 v4 数据根目录后，复制 `Core/Lumi.db`
/// （+ -shm/-wal）到临时副本再打开 —— 既防锁竞争，又保住 WAL 数据，且绝不损坏原件。
/// 会话摘要由 ConversationManager 插件迁移，消息实体必须由本插件独立迁移，
/// 否则升级后旧会话打开是空列表（#394）。
///
/// 设计要点：
/// - **子集 schema**：只带 `ChatMessageEntity` / `ImageAttachmentEntity` 两个实体。
///   类名必须与 v4 实体名一致（见 LegacyV4ChatMessage.swift 的硬约束）。
/// - **allowsSave: true**：SwiftData 打开库时会做 store 元数据校验/轻量迁移；
///   只读打开会因「Cannot migrate store in-place」失败。操作的是临时副本，安全。
/// - **错误交由迁移层处理**：打开或读取失败时抛出，`MessageLegacyMigration`
///   会捕获错误并保留重试机会，不阻塞 onBoot。
/// - **actor 隔离**：DB 复制、ModelContainer 打开与 fetch 都是重 IO，
///   必须在主线程之外执行（对齐 issue #1285 的约定）。
public actor V4MessageReader: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message.v4-reader")
    nonisolated public static let emoji = "💬"
    nonisolated static let verbose = false

    /// v4 数据根目录（原件）；nil 表示未找到旧数据（全新安装）。
    private let sourceRootDirectory: URL?

    /// v4 数据库文件名（与 v4 Configuration.databaseFileName 一致）
    private static let v4DatabaseFileName = "Lumi.db"

    /// 已建立的只读快照（nil 表示尚未打开）
    private var snapshot: Snapshot?

    /// 图片附件按 messageId 分组（惰性构建一次，跨会话复用）。
    private var attachmentsByMessageID: [UUID: [UserImageAttachment]]?

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

    /// 读取 v4 消息表中出现过的全部会话 id（去重）。
    ///
    /// 只物化 `conversationId` 列，避免为枚举会话把整张消息表读进内存。
    public func fetchLegacyConversationIDs() throws -> [UUID] {
        let container = try ensureSnapshot()
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ChatMessageEntity>()
        descriptor.propertiesToFetch = [\.conversationId]
        do {
            let entities = try context.fetch(descriptor)
            return Array(Set(entities.map(\.conversationId)))
        } catch {
            Self.logger.error("\(Self.t)读取 v4 会话 id 列表失败：\(error.localizedDescription)")
            throw error
        }
    }

    /// 读取某会话的全部 v4 历史消息（按 timestamp 升序，转换成 `Message`）。
    ///
    /// - Throws: 快照复制、数据库打开或数据读取失败时抛出，避免把失败误判为空库。
    public func fetchLegacyMessages(for conversationID: UUID) throws -> [Message] {
        let container = try ensureSnapshot()
        let attachments = try ensureAttachmentsByMessageID(container: container)

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.conversationId == conversationID },
            sortBy: [
                SortDescriptor(\.timestamp, order: .forward),
                SortDescriptor(\.id, order: .forward),
            ]
        )

        do {
            let entities = try context.fetch(descriptor)
            return entities.compactMap { Self.convert($0, attachments: attachments[$0.id] ?? []) }
        } catch {
            Self.logger.error("\(Self.t)读取 v4 历史消息失败：\(error.localizedDescription)")
            throw error
        }
    }

    /// 释放只读快照资源（幂等）。
    public func releaseLegacySnapshot() {
        let copyDirectory = snapshot?.copyDirectory
        snapshot = nil
        attachmentsByMessageID = nil
        if let copyDirectory {
            try? FileManager.default.removeItem(at: copyDirectory)
        }
    }

    // MARK: - Snapshot Management

    /// 确保只读快照已建立，返回容器。惰性打开、复用。
    private func ensureSnapshot() throws -> ModelContainer {
        if let snapshot { return snapshot.container }

        guard let root = sourceRootDirectory else {
            throw V4MessageReaderError.legacyDataNotFound
        }

        let originalDB = root
            .appendingPathComponent("Core", isDirectory: true)
            .appendingPathComponent(Self.v4DatabaseFileName, isDirectory: false)

        guard FileManager.default.fileExists(atPath: originalDB.path) else {
            throw V4MessageReaderError.legacyDataNotFound
        }

        // 1. 复制 .db / -shm / -wal 三件套到临时副本（同卷，保 WAL 数据 + 防锁）
        let copyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi_v4_message_migration_\(UUID().uuidString)", isDirectory: true)
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
            try? FileManager.default.removeItem(at: copyDir)
            throw V4MessageReaderError.snapshotCopyFailed(underlying: error)
        }

        let copiedDB = copyDir.appendingPathComponent(Self.v4DatabaseFileName, isDirectory: false)

        // 2. 用 v4 legacy schema 打开副本（allowsSave 原因见类型注释）。
        let schema = Schema([ChatMessageEntity.self, ImageAttachmentEntity.self])
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
                Self.logger.info("\(Self.t)已建立 v4 消息只读快照：\(copiedDB.path)")
            }
            return container
        } catch {
            try? FileManager.default.removeItem(at: copyDir)
            throw V4MessageReaderError.openFailed(underlying: error)
        }
    }

    /// 惰性构建「messageId → 图片附件」分组，跨会话复用，避免逐会话重复全表扫描。
    private func ensureAttachmentsByMessageID(container: ModelContainer) throws -> [UUID: [UserImageAttachment]] {
        if let attachmentsByMessageID { return attachmentsByMessageID }

        let context = ModelContext(container)
        let entities = (try? context.fetch(FetchDescriptor<ImageAttachmentEntity>())) ?? []
        var grouped: [UUID: [UserImageAttachment]] = [:]
        for entity in entities {
            guard let messageID = entity.messageId else { continue }
            grouped[messageID, default: []].append(
                UserImageAttachment(
                    id: entity.id,
                    mimeType: entity.mimeType,
                    base64Data: entity.data.base64EncodedString()
                )
            )
        }
        attachmentsByMessageID = grouped
        return grouped
    }

    // MARK: - Conversion (v4 entity → ProviderMessage.Message)

    /// v4 ChatMessageEntity → Message。
    ///
    /// 保留 id / 会话关联 / 时间顺序 / 正文 / metadata / 工具调用 / 推理内容等；
    /// token 统计在 v4 独立的 MessageMetricsEntity 表（实测多为空），沿袭历史
    /// MessageMigrationJob 不合并，留 nil。未知 role 的行跳过（返回 nil）。
    private static func convert(
        _ entity: ChatMessageEntity,
        attachments: [UserImageAttachment]
    ) -> Message? {
        guard let role = MessageRole(rawValue: entity.role) else { return nil }

        let decoder = JSONDecoder()
        var metadata: [String: String] = [:]
        if let metadataJSON = entity.metadataJSON, !metadataJSON.isEmpty {
            metadata = (try? decoder.decode([String: String].self, from: Data(metadataJSON.utf8))) ?? [:]
        }
        // v4 用户图片存在独立 ImageAttachmentEntity 表；v5 约定序列化进
        // metadata["imageAttachments"]，AgentLoop 靠它把图片挂上后续请求。
        if !attachments.isEmpty {
            metadata.merge(UserAttachmentMetadata.encodeImageAttachments(attachments)) { _, new in new }
        }

        let toolCalls: [MessageToolCall]? = entity.toolCallsJSON.flatMap {
            decodeToolCalls($0)
        }

        return Message(
            id: entity.id,
            conversationID: entity.conversationId,
            role: role,
            content: entity.content,
            createdAt: entity.timestamp,
            metadata: metadata,
            isError: entity.isError,
            providerID: entity.providerId,
            modelName: entity.modelName,
            rawErrorDetail: entity.rawErrorDetail,
            renderKind: entity.renderKind,
            toolCallID: entity.toolCallID,
            reasoningContent: entity.reasoningContent,
            toolCalls: toolCalls
        )
    }

    /// 解码 v4 toolCallsJSON。
    ///
    /// 不能直接解码成 `[MessageToolCall]`：v4 结果里的图片附件字段是
    /// `base64Data`（v5 `MessageImageAttachment` 用 `data`），直接解码会整体失败、
    /// 丢掉全部工具调用。这里用 v4 形状的 DTO 解码后再映射；v4 的 `turnControl`
    /// 等多余键被忽略，v5 新增键（authorizationState 等）缺省为 nil。
    private static func decodeToolCalls(_ json: String) -> [MessageToolCall]? {
        guard let payloads = try? JSONDecoder().decode([V4ToolCallPayload].self, from: Data(json.utf8)) else {
            return nil
        }
        return payloads.map { payload in
            MessageToolCall(
                id: payload.id,
                name: payload.name,
                arguments: payload.arguments,
                result: payload.result.map { result in
                    MessageToolResult(
                        content: result.content,
                        duration: result.duration,
                        isError: result.isError ?? false,
                        imageAttachments: (result.imageAttachments ?? []).map {
                            MessageImageAttachment(data: $0.base64Data, mimeType: $0.mimeType)
                        }
                    )
                },
                displayDescription: payload.displayDescription
            )
        }
    }
}

// MARK: - v4 toolCalls JSON DTO（字段形状与 v4 LumiToolCall/LumiToolResult 一致）

private struct V4ToolCallPayload: Decodable {
    let id: String
    let name: String
    let arguments: String
    let result: V4ToolResultPayload?
    let displayDescription: String?
}

private struct V4ToolResultPayload: Decodable {
    let content: String
    let duration: TimeInterval?
    let isError: Bool?
    let imageAttachments: [V4ImageAttachmentPayload]?
}

private struct V4ImageAttachmentPayload: Decodable {
    let mimeType: String
    let base64Data: String
}

// MARK: - Errors

enum V4MessageReaderError: Error {
    case legacyDataNotFound
    case snapshotCopyFailed(underlying: Error)
    case openFailed(underlying: Error)
}

// MARK: - v4 数据根目录定位

/// 定位 v4 数据根目录（当前 v5 dataRoot 的兄弟目录）。
///
/// 与 `V4DataDirectoryLocator`（ConversationManager 插件内部）逻辑一致：
/// v4 目录名 `db_production_v4`（Debug 另试 `db_debug_v4`）。
enum V4MessageDataDirectoryLocator {
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