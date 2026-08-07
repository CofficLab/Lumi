import Foundation
import LumiKernel
import os
import SuperLogKit

private struct MessageListV1Presentation: Equatable {
    var turnItems: [AgentTurnSummaryItem] = []
    var legacyConclusions: [LumiChatMessage] = []
    var statusMessage: LumiChatMessage?
}

/// V1-only data source that pages AgentTurns and projects each turn to one
/// user-facing response. While a Turn is active, its process is represented by
/// exactly one replaceable status message; streaming/process messages are never
/// part of this presentation.
@MainActor
final class MessageListV1ViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-list.v1-viewmodel")
    nonisolated static let emoji = "📑"
    nonisolated static let verbose = false

    @Published private var presentation = MessageListV1Presentation()
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingEarlier = false
    @Published private(set) var hasEarlierTurns = false

    private let kernel: LumiKernel
    private let builder = AgentTurnSummaryBuilder()
    private let refreshGate = MessageListTailRefreshGate()
    private let pageSize: Int
    private var records: [AgentTurnRecord] = [] // newest first
    private var activeConversationID: UUID?
    /// 激活序列号，用于防止并发 activate 的竞态。
    /// 每次 activate 调用时递增，异步操作完成后检查序列号是否匹配。
    private var activationSequence: UInt64 = 0

    init(kernel: LumiKernel, pageSize: Int = 40) {
        self.kernel = kernel
        self.pageSize = pageSize
    }

    var items: [AgentTurnSummaryItem] { presentation.turnItems }
    var statusMessage: LumiChatMessage? { presentation.statusMessage }
    var usesTurnProjection: Bool { !records.isEmpty }
    var conclusionMessages: [LumiChatMessage] {
        usesTurnProjection
            ? presentation.turnItems.map(\.message)
            : presentation.legacyConclusions
    }
    var displayMessages: [LumiChatMessage] {
        conclusionMessages + (statusMessage.map { [$0] } ?? [])
    }
    var hasVisibleContent: Bool { !displayMessages.isEmpty }

    /// 用户当前选中的对话 ID（来自内核状态，反映真实意图）。
    /// 用于替代 `activeConversationID` 做过期守卫，避免并发 `activate` 导致竞态。
    var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    func activate(conversationID: UUID?) async {
        if Self.verbose {
            Self.logger.info("\(self.t)激活会话：\(conversationID?.uuidString ?? "nil")")
        }
        // 记录当前激活序列号，用于后续异步操作完成后检查是否过期
        activationSequence &+= 1
        let mySequence = activationSequence

        activeConversationID = conversationID
        isLoading = true
        defer { isLoading = false }

        guard let conversationID,
              let turnManager = kernel.agentTurnManager else {
            // 无对话 ID 或无 turnManager 时，清空状态
            if mySequence == activationSequence {
                records = []
                presentation = MessageListV1Presentation()
                hasEarlierTurns = false
            }
            return
        }

        let page = await turnManager.turnRecords(
            for: conversationID,
            limit: pageSize + 1,
            before: nil
        )
        // 检查序列号和 selectedConversationID，确保本次激活仍然有效
        guard mySequence == activationSequence,
              selectedConversationID == conversationID else { return }

        // 只在序列号匹配时更新状态，避免被后续 activate 的结果覆盖
        hasEarlierTurns = page.count > pageSize
        records = Array(page.prefix(pageSize))
        if Self.verbose {
            Self.logger.info("\(self.t)Turn 记录加载完成: \(self.records.count) 条")
        }
        await rebuildItems(for: conversationID, sequence: mySequence)
    }

    /// Refreshes the newest Turn page while retaining any earlier pages the
    /// user already loaded. Returns true only when the visible projection changed.
    @discardableResult
    func refresh() async -> Bool {
        await refreshGate.run { [weak self] in
            guard let self else { return false }
            return await self.performRefresh()
        }
    }

    private func performRefresh() async -> Bool {
        guard let conversationID = activeConversationID,
              let turnManager = kernel.agentTurnManager else { return false }

        let latest = await turnManager.turnRecords(
            for: conversationID,
            limit: pageSize + 1,
            before: nil
        )
        guard selectedConversationID == conversationID else { return false }

        let previousPresentation = presentation
        var byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for record in latest.prefix(pageSize) {
            byID[record.id] = record
        }
        records = byID.values.sorted(by: newestRecordFirst)
        if records.count <= pageSize {
            hasEarlierTurns = latest.count > pageSize
        }
        await rebuildItems(for: conversationID, sequence: activationSequence)
        return presentation != previousPresentation
    }

    /// Prepends one older Turn page and returns the previously oldest visible
    /// Turn ID so the view can preserve its scroll position.
    func loadEarlier() async -> UUID? {
        guard hasEarlierTurns,
              !isLoadingEarlier,
              let conversationID = activeConversationID,
              let cursor = records.last?.id,
              let anchorID = items.first?.id,
              let turnManager = kernel.agentTurnManager else { return nil }

        isLoadingEarlier = true
        defer { isLoadingEarlier = false }

        let page = await turnManager.turnRecords(
            for: conversationID,
            limit: pageSize + 1,
            before: cursor
        )
        guard selectedConversationID == conversationID else { return nil }

        let older = Array(page.prefix(pageSize))
        guard !older.isEmpty else {
            hasEarlierTurns = false
            return nil
        }

        let existingIDs = Set(records.map(\.id))
        records.append(contentsOf: older.filter { !existingIDs.contains($0.id) })
        records.sort(by: newestRecordFirst)
        hasEarlierTurns = page.count > pageSize
        await rebuildItems(for: conversationID, sequence: activationSequence)
        return anchorID
    }

    private func rebuildItems(for conversationID: UUID, sequence: UInt64) async {
        guard let messageManager = kernel.messageManager else {
            if sequence == activationSequence {
                presentation = MessageListV1Presentation()
            }
            return
        }
        let snapshot = await Task.detached(priority: .userInitiated) {
            let messages = messageManager.messages(for: conversationID)
            let status = messageManager.messagePage(
                for: conversationID,
                limit: 1,
                beforeMessageID: nil,
                includesToolMessages: false
            ).last(where: { $0.role == .status })
            return (messages, status)
        }.value
        // 检查序列号，确保本次重建仍然有效
        guard sequence == activationSequence,
              selectedConversationID == conversationID else { return }
        presentation = MessageListV1Presentation(
            turnItems: builder.build(records: records, messages: snapshot.0),
            legacyConclusions: builder.legacyConclusions(from: snapshot.0),
            statusMessage: snapshot.1
        )
    }

    private func newestRecordFirst(_ lhs: AgentTurnRecord, _ rhs: AgentTurnRecord) -> Bool {
        if lhs.startedAt == rhs.startedAt { return lhs.id.uuidString > rhs.id.uuidString }
        return lhs.startedAt > rhs.startedAt
    }
}
