import Foundation
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import LumiLoggingKit

/// 消息读取的范围。
///
/// - `.full`：物化全部列，UI 渲染路径用（需要 `metadata`、错误详情等）。
/// - `.llmContext`：只物化 LLM 上下文需要的列，避免读取与 LLM 无关的大字段。
enum MessageReadScope {
    case full
    case llmContext
}

/// Message Manager Service
@MainActor
public final class MessageManager: MessageManaging, SuperLog {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message.manager")

    /// 数据存储目录（供未来迁移/设置使用）。
    public let dataDirectory: URL

    private let store: MessageStore?
    private let conversations: (any ConversationManaging)?

    /// 内存中的"已通知 UI、尚未落盘"消息缓冲(write-behind 的脏数据)。
    ///
    /// internal 而非 private：测试需要直接构造「磁盘已有旧版本、pending 保留新版本」
    /// 的窗口，后台落盘时序无法在测试里稳定复现。
    nonisolated let pending = PendingMessageBuffer()

    /// 后台 utility 串行落盘队列，保证消息、更新和删除按调用顺序执行。
    ///
    /// 消息先进入 pending buffer，再由该队列 eventual consistency 地落盘；
    /// 因此持久化不会和 Return → 列表首帧争抢主线程资源。
    ///
    /// internal 而非 private：测试需要 suspend/resume 这条队列，确定性地构造
    /// 「insert(A) 已落盘、update(B) 仍在队列里」的窗口来复现 A→B→C 覆盖（#150）。
    nonisolated let persistQueue = DispatchQueue(
        label: "com.coffic.lumi.message.persist",
        qos: .utility,
        autoreleaseFrequency: .workItem
    )

    // MARK: - Message Insertion Observers

    private var messageInsertedObservers: [WeakMessageInsertedObserver] = []
    private var messageChangeObservers: [WeakMessageChangeObserver] = []

    public init(
        store: MessageStore?,
        dataDirectory: URL,
        conversations: (any ConversationManaging)? = nil
    ) {
        self.store = store
        self.dataDirectory = dataDirectory
        self.conversations = conversations
        if Self.verbose {
            Self.logger.info("\(Self.t)MessageManager initialized, store=\(store == nil ? "nil" : "ready")")
        }
    }

    // MARK: - Pending Buffer (write-behind 脏数据,锁保护)

    /// 把一条消息加入待落盘缓冲(去重:同 id 已在则替换,保持时间升序)。
    /// 返回本次代次，落盘闭包据此做版本门控 dequeue（#150）。
    @discardableResult
    private func enqueuePending(_ message: Message, conversationID: UUID) -> Int {
        pending.enqueue(message, conversationID: conversationID)
    }

    /// 从待落盘缓冲移除一条(后台落盘成功后调用)。nonisolated：锁保护，可在持久化队列直接调用。
    /// 版本门控：只移除落盘闭包实际写入的那一代，避免旧写回撤掉已更新的新版本（#150）。
    private nonisolated func dequeuePending(id: UUID, conversationID: UUID, generation: Int) {
        pending.dequeue(id: id, conversationID: conversationID, generation: generation)
    }

    /// 合并磁盘页与待落盘消息(read-your-writes),返回按时间升序、去重、限量的结果。
    ///
    /// 策略:把 pending 中属于本会话、满足过滤(同 includesToolMessages)的消息并入磁盘页,
    /// 去重(同 id 取 pending 版本——它更新),整体按 (createdAt, id) 升序排序后取尾部 limit 条。
    ///
    /// **游标分页(`beforeMessageID` 非 nil)不合并 pending**:游标分页是"向上翻历史"场景,
    /// 翻到的都是较早消息,那时尾部的新消息早已落盘、pending 为空,合并无意义反而易错。
    /// pending 只需参与"取最近一页"(无游标)的合并 —— 那正是 UI 实时展示的路径。
    private nonisolated static func mergedPage(
        disk: [Message],
        pendingMessages: [Message],
        conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool,
        limit: Int
    ) -> [Message] {
        guard beforeMessageID == nil else { return disk }

        let pending = pendingMessages.filter {
            includesToolMessages || $0.role != .tool
        }
        if Self.verbose {
            let cursorState = beforeMessageID == nil ? "nil" : "set"
            Self.logger.info("\(Self.t)mergedPage conversation=\(conversationID.uuidString.prefix(8)) disk=\(disk.count) pending=\(pending.count) before=\(cursorState)")
        }

        guard !pending.isEmpty else { return disk }

        // pending 里的同 id 版本比磁盘新（例如工具结果刚写回、尚未落盘），
        // 必须以 pending 覆盖磁盘，否则读路径会把旧版本继续展示出去。
        var mergedByID = Dictionary(uniqueKeysWithValues: disk.map { ($0.id, $0) })
        for message in pending {
            mergedByID[message.id] = message
        }
        let merged = mergedByID.values.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id < rhs.id }
            return lhs.createdAt < rhs.createdAt
        }
        return Array(merged.suffix(limit))
    }

    /// 按 id 合并磁盘与 pending，pending 版本始终胜出。
    private nonisolated static func mergePendingVersions(
        _ disk: [Message],
        _ pendingMessages: [Message]
    ) -> [Message] {
        guard !pendingMessages.isEmpty else { return disk }
        var mergedByID = Dictionary(uniqueKeysWithValues: disk.map { ($0.id, $0) })
        for message in pendingMessages {
            mergedByID[message.id] = message
        }
        return mergedByID.values.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id < rhs.id }
            return lhs.createdAt < rhs.createdAt
        }
    }

    // MARK: - MessageManaging (reads)

    public func messages(for conversationID: UUID) -> [Message] {
        // 工具结果可能已通知 UI、但落盘仍在 persistQueue 排队；补丁叠加在磁盘
        // 版本上，保证 AgentLoop 下一轮读到的是带结果的消息。pending 消息本身
        // 已是最新版本，合并时仍然覆盖打过补丁的磁盘版本。
        let diskMessages = Self.applyingToolResultPatches(
            store?.fetchMessages(conversationId: conversationID) ?? [],
            patches: pending.toolResultPatches(for: conversationID)
        )
        let pendingMessages = pending.snapshot(for: conversationID)

        // AgentLoop uses this method as the durable source of truth before
        // starting the next LLM iteration. Assistant/tool messages are persisted
        // asynchronously, so reading only from disk can briefly hide a freshly
        // inserted tool result and cause the same tool call to execute again.
        // Merge pending writes here and de-duplicate by message ID so a message
        // is represented exactly once during that window. The pending version
        // wins because it carries the newest edits (e.g. a tool result that has
        // not been persisted yet).
        let all = Self.mergePendingVersions(diskMessages, pendingMessages)

        if Self.verbose {
            Self.logger.info("\(Self.t)messages(for:) conversation=\(conversationID.uuidString.prefix(8)) messages=\(all.count)")
        }

        return all
    }

    /// 在后台读取并组装完整消息快照，避免 SwiftData 解码和全量排序阻塞 MainActor。
    public func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        await readSnapshot(in: conversationID, priority: .utility)
    }

    /// 在后台读取首条用户消息，避免标题服务为了一个字段物化整个会话。
    public func firstUserMessage(in conversationID: UUID) async -> Message? {
        let store = self.store
        let pending = self.pending
        return await Task.detached(priority: .utility) {
            var candidates = pending.snapshot(for: conversationID).filter {
                $0.role == .user && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if let persisted = store?.fetchFirstUserMessage(conversationId: conversationID) {
                candidates.append(persisted)
            }
            return candidates.min {
                if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                return $0.createdAt < $1.createdAt
            }
        }.value
    }

    /// LLM 回合读取属于发送关键路径，使用较高优先级，但仍不在 MainActor 执行。
    public func messagesForLLM(in conversationID: UUID) async -> [Message] {
        await readSnapshot(in: conversationID, priority: .userInitiated, scope: .llmContext)
    }

    private func readSnapshot(
        in conversationID: UUID,
        priority: TaskPriority,
        scope: MessageReadScope = .full
    ) async -> [Message] {
        let store = self.store
        let pending = self.pending
        return await Task.detached(priority: priority) {
            // LLM 上下文只需要 content + reasoningContent + toolCalls，
            // 外加时间线标记（`renderKind` / `lumi.timelineEvent`）与附件
            // （`imageAttachments` / `fileAttachments`），用窄读取避开
            // `metadataJson`（35MB）整份解码与 `rawStreamEventsJSON`（47MB）。
            let diskMessages: [Message] = switch scope {
            case .full:
                store?.fetchMessages(conversationId: conversationID) ?? []
            case .llmContext:
                store?.fetchMessagesForLLMContext(conversationId: conversationID) ?? []
            }
            let pendingMessages = pending.snapshot(for: conversationID)
            let patchedDiskMessages = Self.applyingToolResultPatches(
                diskMessages,
                patches: pending.toolResultPatches(for: conversationID)
            )
            return Self.mergePendingVersions(patchedDiskMessages, pendingMessages)
        }.value
    }

    public func message(id: UUID, in conversationID: UUID) -> Message? {
        if let pendingMessage = pending.snapshot(for: conversationID).first(where: { $0.id == id }) {
            return pendingMessage
        }
        guard let diskMessage = store?.fetchMessage(id: id) else { return nil }
        return Self.applyingToolResultPatches(
            [diskMessage],
            patches: pending.toolResultPatches(for: conversationID)
        ).first
    }

    public func lastMessage(in conversationID: UUID) -> Message? {
        messages(for: conversationID).last
    }

    public func messageCount(for conversationID: UUID) -> Int {
        // 与旧版语义一致：只统计磁盘，不合并 pending（pending 是瞬时增量，
        // 计数场景（空对话判定等）以落盘为准）。
        store?.messageCount(conversationId: conversationID) ?? 0
    }

    /// 聚合日统计的公共合并逻辑（消息条数 / token 总数各传一个标记）。
    ///
    /// - Important: 口径是「磁盘侧排除 pending + pending 侧全部补计」。
    ///   `persistLater` 分两步（先 `store.insertMessage`、再 `dequeuePending`），
    ///   中间存在窗口：磁盘**已**含该消息、pending**仍**保留它。两侧简单相加会
    ///   把同一条统计两次——实测 20 轮中第 13 轮 `dailyTokenCounts` 得到 27
    ///   （应为 17，input 的 10 被算了两遍）。
    ///
    ///   按 id 排除后，pending 里的消息**无论此刻是否已落盘，都只由 pending 侧计一次**，
    ///   结果与两侧快照的先后顺序无关。反过来若「磁盘侧照算、再回报哪些已落盘让
    ///   调用方跳过」，一旦消息已移出 pending 而磁盘尚不可见，两侧都不计 → 少算。
    ///
    /// - Important: pending 侧只补齐「创建时间不早于 `since`」的消息，
    ///   与磁盘侧的过滤条件保持一致。
    private nonisolated static func mergeDailyAggregate(
        pendingMessages: [Message],
        since: Date,
        store: MessageStore?,
        countTokens: Bool,
        conversationIDs: [String]?
    ) -> [Date: Int] {
        // 范围里没有任何会话 → 结果必然为空，不要把全量拉出来再过滤。
        if let conversationIDs, conversationIDs.isEmpty { return [:] }
        let allowed = conversationIDs.map(Set.init)

        let eligible = pendingMessages.filter { message in
            guard message.createdAt >= since else { return false }
            guard let allowed else { return true }
            return allowed.contains(message.conversationID.uuidString)
        }
        guard !eligible.isEmpty else {
            // pending 为空：直接用磁盘口径。必须按 countTokens 分派，
            // 不可无条件用 dailyMessageCounts——那会把 token 读成条数。
            guard let store else { return [:] }
            return store.dailyAggregate(
                since: since,
                excludingIDs: [],
                countTokens: countTokens,
                conversationIDs: conversationIDs
            )
        }

        guard let store else {
            // store 未就绪：只靠 pending 尽力而为（read-your-writes）。
            return Self.aggregatePendingOnly(eligible, countTokens: countTokens)
        }

        let ids = Set(eligible.map { $0.id.uuidString })
        // 磁盘侧排除这批 id，pending 侧再全部补计 → 每条消息恰好计一次。
        var result = store.dailyAggregate(
            since: since,
            excludingIDs: ids,
            countTokens: countTokens,
            conversationIDs: conversationIDs
        )
        let calendar = Calendar.current
        for message in eligible {
            let value = countTokens
                ? (message.inputTokenCount ?? 0) + (message.outputTokenCount ?? 0)
                : 1
            guard value > 0 else { continue }
            result[calendar.startOfDay(for: message.createdAt), default: 0] += value
        }
        return result
    }

    private nonisolated static func aggregatePendingOnly(
        _ messages: [Message],
        countTokens: Bool
    ) -> [Date: Int] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for message in messages {
            let value = countTokens
                ? (message.inputTokenCount ?? 0) + (message.outputTokenCount ?? 0)
                : 1
            guard value > 0 else { continue }
            counts[calendar.startOfDay(for: message.createdAt), default: 0] += value
        }
        return counts
    }

    public func dailyMessageCounts(since: Date) -> [Date: Int] {
        Self.mergeDailyAggregate(
            pendingMessages: pending.snapshotAll(),
            since: since,
            store: store,
            countTokens: false,
            conversationIDs: nil
        )
    }

    /// 在后台读取并聚合消息日统计，避免 Heatmap 打开或刷新时阻塞 MainActor。
    public func dailyMessageCountsAsync(since: Date) async -> [Date: Int] {
        await dailyMessageCountsAsync(since: since, conversationIDs: nil)
    }

    /// 按会话集合过滤的消息日统计。
    ///
    /// `conversationIDs` 为 nil 表示不限会话；空数组表示该范围内没有任何会话，
    /// 结果为空——绝不退化成全量统计。
    public func dailyMessageCountsAsync(since: Date, conversationIDs: [String]?) async -> [Date: Int] {
        let store = self.store
        // 先在调用方快照 pending：detach 之后再取会拿到**另一个时间点**的缓冲，
        // 与随后的磁盘读取不构成同一组判据，导致漏算。
        let pendingSnapshot = pending.snapshotAll()
        return await Task.detached(priority: .utility) {
            Self.mergeDailyAggregate(
                pendingMessages: pendingSnapshot,
                since: since,
                store: store,
                countTokens: false,
                conversationIDs: conversationIDs
            )
        }.value
    }

    public func dailyTokenCounts(since: Date) -> [Date: Int] {
        Self.mergeDailyAggregate(
            pendingMessages: pending.snapshotAll(),
            since: since,
            store: store,
            countTokens: true,
            conversationIDs: nil
        )
    }

    /// 在后台读取并聚合 token 日统计，保留 pending 消息的 read-your-writes 语义。
    public func dailyTokenCountsAsync(since: Date) async -> [Date: Int] {
        await dailyTokenCountsAsync(since: since, conversationIDs: nil)
    }

    /// 按会话集合过滤的 token 日统计，口径与消息日统计一致。
    public func dailyTokenCountsAsync(since: Date, conversationIDs: [String]?) async -> [Date: Int] {
        let store = self.store
        // 先在调用方快照 pending：detach 之后再取会拿到**另一个时间点**的缓冲，
        // 与随后的磁盘读取不构成同一组判据，导致漏算。
        let pendingSnapshot = pending.snapshotAll()
        return await Task.detached(priority: .utility) {
            Self.mergeDailyAggregate(
                pendingMessages: pendingSnapshot,
                since: since,
                store: store,
                countTokens: true,
                conversationIDs: conversationIDs
            )
        }.value
    }


    public func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) -> [Message] {
        guard let store else {
            // store 未就绪:仍尝试返回 pending(read-your-writes,哪怕磁盘不可用)。
            return Self.mergedPage(
                disk: [],
                pendingMessages: pending.snapshot(for: conversationID),
                conversationID: conversationID,
                beforeMessageID: beforeMessageID,
                includesToolMessages: includesToolMessages, limit: limit
            )
        }
        let disk = Self.applyingToolResultPatches(
            store.fetchMessagePage(
                conversationId: conversationID,
                limit: limit,
                beforeMessageID: beforeMessageID,
                includesToolMessages: includesToolMessages
            ),
            patches: pending.toolResultPatches(for: conversationID)
        )
        return Self.mergedPage(
            disk: disk,
            pendingMessages: pending.snapshot(for: conversationID),
            conversationID: conversationID,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages, limit: limit
        )
    }

    /// 异步分页查询：数据库分页和 pending 合并均在后台执行，避免阻塞 MainActor。
    public func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) async -> [Message] {
        guard limit > 0 else { return [] }
        let store = self.store
        let pending = self.pending
        return await Task.detached(priority: .utility) {
            let disk = Self.applyingToolResultPatches(
                store?.fetchMessagePage(
                    conversationId: conversationID,
                    limit: limit,
                    beforeMessageID: beforeMessageID,
                    includesToolMessages: includesToolMessages
                ) ?? [],
                patches: pending.toolResultPatches(for: conversationID)
            )
            return Self.mergedPage(
                disk: disk,
                pendingMessages: pending.snapshot(for: conversationID),
                conversationID: conversationID,
                beforeMessageID: beforeMessageID,
                includesToolMessages: includesToolMessages,
                limit: limit
            )
        }.value
    }

    /// 是否有更早消息（UI 顶部"加载更早"按钮显隐）。
    public func hasEarlierMessages(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) -> Bool {
        store?.hasEarlierMessages(
            conversationId: conversationID,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages
        ) ?? false
    }

    /// 异步探测历史分页边界，避免在 MainActor 同步访问 SwiftData。
    public func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) async -> Bool {
        let store = self.store
        return await Task.detached(priority: .utility) {
            store?.hasEarlierMessages(
                conversationId: conversationID,
                beforeMessageID: beforeMessageID,
                includesToolMessages: includesToolMessages
            ) ?? false
        }.value
    }

    // MARK: - MessageManaging (writes)

    public func insertMessage(_ message: Message, to conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)insertMessage called ➡️ messageConversation=\(message.conversationID.uuidString.prefix(8)) targetConversation=\(conversationID.uuidString.prefix(8)) role=\(message.role.rawValue) contentChars=\(message.content.count) toolCalls=\(message.toolCalls?.count ?? 0)")
        }

        // Ensure message has the correct conversationID
        var messageToInsert = message
        if messageToInsert.conversationID != conversationID {
            if Self.verbose {
                Self.logger.info("\(Self.t)conversationID mismatch, creating new message with target ID")
            }
            messageToInsert = Message(
                id: messageToInsert.id,
                conversationID: conversationID,
                role: messageToInsert.role,
                content: messageToInsert.content,
                createdAt: messageToInsert.createdAt,
                turnID: messageToInsert.turnID,
                metadata: messageToInsert.metadata,
                isError: messageToInsert.isError,
                providerID: messageToInsert.providerID,
                modelName: messageToInsert.modelName,
                rawErrorDetail: messageToInsert.rawErrorDetail,
                httpStatusCode: messageToInsert.httpStatusCode,
                httpBody: messageToInsert.httpBody,
                renderKind: messageToInsert.renderKind,
                preferredRendererID: messageToInsert.preferredRendererID,
                toolCallID: messageToInsert.toolCallID,
                reasoningContent: messageToInsert.reasoningContent,
                toolCalls: messageToInsert.toolCalls,
                inputTokenCount: messageToInsert.inputTokenCount,
                outputTokenCount: messageToInsert.outputTokenCount,
                cachedInputTokenCount: messageToInsert.cachedInputTokenCount,
                cacheWriteInputTokenCount: messageToInsert.cacheWriteInputTokenCount,
                cacheTotalInputTokenCount: messageToInsert.cacheTotalInputTokenCount,
                responseID: messageToInsert.responseID,
                requestID: messageToInsert.requestID,
                rawResponseJSON: messageToInsert.rawResponseJSON,
                rawStreamEventsJSON: messageToInsert.rawStreamEventsJSON,
                stopReason: messageToInsert.stopReason,
                latencyMs: messageToInsert.latencyMs,
                timeToFirstTokenMs: messageToInsert.timeToFirstTokenMs,
                streamingDurationMs: messageToInsert.streamingDurationMs
            )
        }

        // 瞬时 activity 属于 ConversationStateProvider，不属于消息时间线。
        if messageToInsert.role == .status || messageToInsert.metadata["isTransientStatus"] == "true" {
            Self.logger.error("\(Self.t)reject transient message conversation=\(conversationID.uuidString.prefix(8)) role=\(messageToInsert.role.rawValue); use ConversationStateProvider")
            return
        }

        // 0) 非瞬时消息:刷新会话最后消息时间,让「最近有消息的对话」在列表中置顶。
        conversations?.markConversationActive(id: conversationID, messageDate: messageToInsert.createdAt)

        // 1) 写入内存缓冲,立即通知 UI —— UI 这一刻就能从读路径看到它(read-your-writes)。
        let generation = enqueuePending(messageToInsert, conversationID: conversationID)
        notifyMessageChange(.inserted(messageToInsert, conversationID: conversationID))
        notifyMessageInsertedObservers(messageToInsert, conversationID: conversationID)

        // 2) 所有非瞬时消息统一后台串行落盘。消息已经在 pending buffer
        //    中对 UI 和 AgentLoop 可见，不能让磁盘 I/O 阻塞发送主线程。
        persistLater(messageToInsert, conversationID: conversationID, generation: generation)
    }

    /// 后台串行落盘 + 从缓冲移除(成功后)。失败则保留在缓冲,下次启动可补救。
    /// 只移除本次写入的代次：若落盘期间消息已被更新到新版本，insert 不得撤掉新版本（#150）。
    private func persistLater(_ message: Message, conversationID: UUID, generation: Int) {
        let store = self.store
        persistQueue.async { [weak self] in
            guard let store else { return }
            do {
                try store.insertMessage(message)
                // dequeuePending 是 nonisolated + 锁保护,可在本队列直接调用。
                self?.dequeuePending(id: message.id, conversationID: conversationID, generation: generation)
                Task { @MainActor [weak self] in
                    self?.notifyMessageChange(.persisted(message, conversationID: conversationID))
                }
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to persist message in background: \(error)")
                }
            }
        }
    }

    public func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        if Self.verbose {
            Self.logger.info("\(Self.t)updateMessage ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(id.uuidString.prefix(8))…, newContentChars=\(content.count)")
        }
        let pendingUpdate = pending.update(id: id, conversationID: conversationID) { message in
            message.content = content
        }
        if let pendingUpdate {
            // Keep the update ordered after the original write-behind insert.
            // 携带本次代次：落盘成功后只撤掉这一代，期间若再更新到更新版本则不撤（#150）。
            persistUpdatedMessage(pendingUpdate.message, conversationID: conversationID, generation: pendingUpdate.generation)
        } else {
            _ = store?.updateMessage(id: id, content: content)
        }
        notifyMessageChange(.updated(conversationID: conversationID))
    }

    public func deleteMessage(id: UUID, in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)deleteMessage ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(id.uuidString.prefix(8))…")
        }
        pending.dequeue(id: id, conversationID: conversationID)
        // 用户消息现在可能仍在后台插入队列中。同步排空同一队列，
        // 避免 delete 先执行、随后 insert 又把消息复活。
        persistQueue.sync {
            _ = store?.deleteMessage(id: id)
            pending.dequeueToolResults(messageID: id, conversationID: conversationID)
        }
        notifyMessageChange(.deleted(messageID: id, conversationID: conversationID))
    }

    public func clearMessages(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)clearMessages ➡️ conversation=\(conversationID.uuidString.prefix(8))…")
        }
        // Drain the write-behind queue before deleting. Otherwise an older
        // assistant/tool write could land after the delete and resurrect data.
        persistQueue.sync {
            _ = store?.deleteAllMessages(conversationId: conversationID)
            pending.clear(conversationID: conversationID)
        }
        notifyMessageChange(.cleared(conversationID: conversationID))
    }

    // MARK: - Shutdown Flush

    /// 排空 write-behind 落盘队列，等待所有已接受的写入收敛到磁盘后才返回。
    ///
    /// 内核停止 / 插件卸载时调用（#152）：消息先进 pending buffer 再后台串行落盘，
    /// 正常退出前若不排空，最后一条用户消息 / 助手回复 / 工具结果只存在于内存，
    /// 重启后丢失。`persistQueue` 串行，`sync` 屏障返回时此前 enqueue 的 insert /
    /// update / 工具结果写回全部执行完毕。
    ///
    /// nonisolated：只访问 nonisolated 的 `persistQueue`，可在任意线程调用。队列块内
    /// 只做 store 写入 + 锁保护的 dequeue + 异步 `Task { @MainActor }` 通知，不同步
    /// 回跳 MainActor，故主线程在 shutdown 等待不会死锁（与 deleteMessage /
    /// clearMessages 的排空同一形态）。
    public nonisolated func flushPendingWrites() {
        persistQueue.sync {}
    }

    // MARK: - Tool Call Result Update

    public func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String? = nil
    ) {
        if Self.verbose {
            Self.logger.info("\(Self.t)updateToolCallResult begin conversation=\(conversationID.uuidString.prefix(8))…, message=\(assistantMessageID.uuidString.prefix(8))…, toolCall=\(toolCallID), contentChars=\(result.content.count), isError=\(result.isError)")
        }

        // pending 命中：纯内存更新，落盘走后台串行队列。
        var updatedToolCalls: [MessageToolCall]?
        let hit = pending.update(id: assistantMessageID, conversationID: conversationID) { message in
            guard var toolCalls = message.toolCalls,
                  let index = toolCalls.firstIndex(where: { $0.id == toolCallID })
            else { return }
            toolCalls[index].result = result
            if let authorizationState {
                toolCalls[index].authorizationState = authorizationState
            }
            message.toolCalls = toolCalls
            updatedToolCalls = toolCalls
        }
        if let hit {
            // update 已 bump generation（即使 toolCall 未命中也无条件 bump，避免重复写回
            // 产生孤儿代次）。命中时写回新 toolCalls；未命中时把原 toolCalls 原样落盘，
            // 让这次 bump 出的 generation 仍被一次排空写消费掉，否则 pending 永久泄漏（#150）。
            let toolCalls = updatedToolCalls ?? hit.message.toolCalls ?? []
            if updatedToolCalls == nil {
                Self.logger.warning("\(Self.t)updateToolCallResult miss toolCall=\(toolCallID), message=\(assistantMessageID.uuidString.prefix(8))…")
            }
            persistUpdatedToolCalls(toolCalls, messageID: assistantMessageID, conversationID: conversationID, generation: hit.generation)
            notifyMessageChange(.updated(conversationID: conversationID))
            return
        }

        // 非 pending：主线程不做任何 SwiftData fetch / 编码 / save（issue #1229）。
        //
        // 补丁先入 write-behind 缓冲，读路径立即可见：AgentLoop 下一轮用
        // `messages(for:)` 作为事实来源，看不到工具结果就会重复执行同一个工具。
        // 真正的 fetch + 编码 + save 交给串行落盘队列（与其他写回保持顺序），
        // 完成后撤掉补丁并再通知一次 UI。
        pending.enqueueToolResult(
            PendingMessageBuffer.ToolResultPatch(result: result, authorizationState: authorizationState),
            messageID: assistantMessageID,
            toolCallID: toolCallID,
            conversationID: conversationID
        )
        notifyMessageChange(.updated(conversationID: conversationID))

        let store = self.store
        let pending = self.pending
        persistQueue.async { [weak self] in
            let saved = store?.applyToolCallResult(
                messageID: assistantMessageID,
                toolCallID: toolCallID,
                result: result,
                authorizationState: authorizationState
            ) ?? false
            pending.dequeueToolResult(
                messageID: assistantMessageID,
                toolCallID: toolCallID,
                conversationID: conversationID
            )
            if !saved {
                Self.logger.warning("\(Self.t)工具结果落盘失败 message=\(assistantMessageID.uuidString.prefix(8))…, toolCall=\(toolCallID)")
            }
            Task { @MainActor [weak self] in
                self?.notifyMessageChange(.updated(conversationID: conversationID))
            }
        }
    }

    /// 把尚未落盘的工具结果补丁合并进读结果（read-your-writes）。
    ///
    /// 补丁只在「助手消息已落盘、工具结果刚写回」的窗口内存在，通常为空，
    /// 此时直接返回原数组，不做任何拷贝。
    private nonisolated static func applyingToolResultPatches(
        _ messages: [Message],
        patches: [UUID: [String: PendingMessageBuffer.ToolResultPatch]]
    ) -> [Message] {
        guard !patches.isEmpty else { return messages }
        return messages.map { message in
            guard let messagePatches = patches[message.id],
                  var toolCalls = message.toolCalls, !toolCalls.isEmpty
            else { return message }
            var didPatch = false
            for (toolCallID, patch) in messagePatches {
                guard let index = toolCalls.firstIndex(where: { $0.id == toolCallID }) else { continue }
                toolCalls[index].result = patch.result
                if let authorizationState = patch.authorizationState {
                    toolCalls[index].authorizationState = authorizationState
                }
                didPatch = true
            }
            guard didPatch else { return message }
            var updated = message
            updated.toolCalls = toolCalls
            return updated
        }
    }

    private func persistUpdatedMessage(
        _ message: Message,
        conversationID: UUID,
        generation: Int
    ) {
        let store = self.store
        persistQueue.async { [weak self] in
            let saved = store?.updateMessage(id: message.id, content: message.content) ?? false
            if saved {
                self?.dequeuePending(id: message.id, conversationID: conversationID, generation: generation)
            } else {
                // 落盘失败（磁盘无记录 / 读失败 / save 失败）：必须保留 pending。
                // 否则消息既不在磁盘也不在内存，从所有读路径静默消失（#151）。
                // 与 persistLater 的 catch 同形态：保留缓冲 + 暴露可观察错误。
                Self.logger.error("\(Self.t)更新落盘失败，保留 pending message=\(message.id.uuidString.prefix(8))… conversation=\(conversationID.uuidString.prefix(8))…")
            }
        }
    }

    private func persistUpdatedToolCalls(
        _ toolCalls: [MessageToolCall],
        messageID: UUID,
        conversationID: UUID,
        generation: Int
    ) {
        let store = self.store
        persistQueue.async { [weak self] in
            let saved = store?.updateToolCalls(id: messageID, toolCalls: toolCalls) ?? false
            if saved {
                self?.dequeuePending(id: messageID, conversationID: conversationID, generation: generation)
            } else {
                // 落盘失败：保留 pending，避免消息从所有读路径静默消失（#151 同形态）。
                Self.logger.error("\(Self.t)工具调用落盘失败，保留 pending message=\(messageID.uuidString.prefix(8))… conversation=\(conversationID.uuidString.prefix(8))…")
            }
        }
    }

    // MARK: - Notification

    // MARK: - Message Insertion Observation

    @discardableResult
    public func addMessageInsertedObserver(
        _ callback: @escaping (Message, UUID) -> Void
    ) -> any MessageInsertedObserverHandle {
        let handle = MessageInsertedObserverHandleImpl(owner: self, callback: callback)
        self.messageInsertedObservers.append(WeakMessageInsertedObserver(handle))
        if Self.verbose {
            Self.logger.info("\(self.t)message inserted observer added, total=\(self.messageInsertedObservers.count)")
        }
        return handle
    }

    @discardableResult
    public func addMessageChangeObserver(
        _ callback: @escaping (MessageChange) -> Void
    ) -> any MessageChangeObserverHandle {
        let handle = MessageChangeObserverHandleImpl(owner: self, callback: callback)
        self.messageChangeObservers.append(WeakMessageChangeObserver(handle))
        return handle
    }

    fileprivate func removeMessageInsertedObserver(_ handle: MessageInsertedObserverHandleImpl) {
        self.messageInsertedObservers.removeAll { $0.handle === handle }
        if Self.verbose {
            Self.logger.info("\(self.t)message inserted observer removed, remaining=\(self.messageInsertedObservers.count)")
        }
    }

    fileprivate func removeMessageChangeObserver(_ handle: MessageChangeObserverHandleImpl) {
        self.messageChangeObservers.removeAll { $0.handle === handle }
    }

    private func notifyMessageInsertedObservers(_ message: Message, conversationID: UUID) {
        messageInsertedObservers.removeAll { $0.handle == nil }
        let observers = messageInsertedObservers
        for observer in observers {
            observer.handle?.invoke(message, conversationID)
        }
    }

    private func notifyMessageChange(_ change: MessageChange) {
        messageChangeObservers.removeAll { $0.handle == nil }
        let observers = messageChangeObservers
        for observer in observers {
            observer.handle?.invoke(change)
        }
    }
}

// MARK: - Message Inserted Observer Handle

@MainActor
private final class MessageInsertedObserverHandleImpl: MessageInsertedObserverHandle {
    private weak var owner: MessageManager?
    private let callback: (Message, UUID) -> Void
    private var isCancelled = false

    init(owner: MessageManager, callback: @escaping (Message, UUID) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeMessageInsertedObserver(self)
    }

    fileprivate func invoke(_ message: Message, _ conversationID: UUID) {
        guard !isCancelled else { return }
        callback(message, conversationID)
    }
}

@MainActor
private final class WeakMessageInsertedObserver {
    fileprivate weak var handle: MessageInsertedObserverHandleImpl?
    init(_ handle: MessageInsertedObserverHandleImpl) { self.handle = handle }
}

@MainActor
private final class MessageChangeObserverHandleImpl: MessageChangeObserverHandle {
    private weak var owner: MessageManager?
    private let callback: (MessageChange) -> Void
    private var isCancelled = false

    init(owner: MessageManager, callback: @escaping (MessageChange) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeMessageChangeObserver(self)
    }

    fileprivate func invoke(_ change: MessageChange) {
        guard !isCancelled else { return }
        callback(change)
    }
}

@MainActor
private final class WeakMessageChangeObserver {
    fileprivate weak var handle: MessageChangeObserverHandleImpl?
    init(_ handle: MessageChangeObserverHandleImpl) { self.handle = handle }
}
