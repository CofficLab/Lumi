import Foundation
import ProviderConversation
import ProviderMessage

/// Message List Row Builder
///
/// 负责把「展示用的最终行序列」的合并规则收敛在视图模型层。
/// **纯数据库驱动**：输入只有真实落库消息（`persisted`，已由 `MessageManaging`
/// 合并了瞬时 status 行），不再拼接任何流式临时行。
///
/// status 行（"正在思考…"等）始终保留显示 —— 它是流式期间唯一的进度反馈，
/// 由 `AgentTurn` 生命周期结束时清除，不在此处丢弃。
///
/// 此外，这里**无条件剔除独立的 `.tool` 结果行**（对齐旧版行为：旧版分页在磁盘读取
/// 时就用 `includesToolMessages=false` 排除了 `.tool` 行，UI 从不展示工具结果消息）。
/// 工具信息仍通过助手消息内联的 toolCalls（`tool-step-group` / `turn-activity`）呈现，
/// 避免重复展示；仅展示层过滤，持久化与 LLM 历史不受影响。
///
/// 本 builder 还会把**连续多条**「只含工具调用的助手消息」（`isToolExecutionOnly`）合并成
/// **一条合成消息**（`renderKind == "tool-step-group"`），其 `toolCalls` 为各消息的平铺。
/// 这样它们在 UI 上呈现为一个整体（一个气泡 / 一个可折叠步骤组），而不是 N 个独立行。
/// 合成消息只在展示层生成，绝不落库、不进 LLM 历史。
@MainActor
struct MessageListRowBuilder {
    func build(
        persisted: [Message],
        conversationID: UUID?,
        verbosity: ResponseVerbosity
    ) -> [Message] {
        buildHistory(
            persisted: persisted,
            conversationID: conversationID,
            verbosity: verbosity
        )
    }

    /// 构建稳定的历史展示行。纯数据库驱动，不再随流式 token 重建 ——
    /// 仅在落库消息变化（新增/编辑/删除）或流式行可见性翻转（nil↔非 nil）时触发。
    ///
    /// - Parameter hidesStatus: 流式行可见时应丢弃历史里的 `.status` 行
    ///   （"正在思考…"等），否则会与流式行同时显示。
    func buildHistory(
        persisted: [Message],
        conversationID: UUID?,
        verbosity: ResponseVerbosity,
        hidesStatus: Bool = false
    ) -> [Message] {
        guard conversationID != nil else { return persisted }

        // 无条件剔除独立的 .tool 结果行（对齐旧版：旧版分页在磁盘读取时即
        // 用 includesToolMessages=false 排除 .tool 行，UI 从不展示工具结果消息）。
        // 工具信息由助手消息内联的 toolCalls（tool-step-group / turn-activity）呈现。
        let filtered = persisted.filter { message in
            if message.role == .tool { return false }
            if hidesStatus, message.role == .status { return false }
            return true
        }

        return Self.mergeConsecutiveToolExecutionMessages(filtered)
    }

    /// 把同一 Turn 中连续的 `isToolExecutionOnly` 助手消息合并成一条活动消息。
    /// 新消息使用 `renderKind == "turn-activity"`；没有 turnID 的历史消息继续使用
    /// `"tool-step-group"`，保持旧数据的展示兼容。
    ///
    /// 单条此类消息也走合成路径（行为等价，仅多一个 renderKind 标记）。
    /// 合成消息复用组内首条消息的 id/conversationID/createdAt，保证稳定。
    private static func mergeConsecutiveToolExecutionMessages(
        _ messages: [Message]
    ) -> [Message] {
        var result: [Message] = []
        var currentGroup: [Message] = []
        var currentTurnID: UUID?
        var turnGroups: [UUID: [Message]] = [:]
        var turnGroupIndices: [UUID: Int] = [:]

        func flushGroup() {
            guard !currentGroup.isEmpty else { return }
            result.append(makeToolStepGroup(from: currentGroup))
            currentGroup = []
            currentTurnID = nil
        }

        for message in messages {
            if message.isToolExecutionOnly {
                if let turnID = message.turnID {
                    flushGroup()
                    turnGroups[turnID, default: []].append(message)
                    let group = turnGroups[turnID] ?? []
                    if let index = turnGroupIndices[turnID] {
                        result[index] = makeToolStepGroup(from: group)
                    } else {
                        turnGroupIndices[turnID] = result.count
                        result.append(makeToolStepGroup(from: group))
                    }
                } else {
                    if !currentGroup.isEmpty, currentTurnID != nil {
                        flushGroup()
                    }
                    currentGroup.append(message)
                    currentTurnID = nil
                }
            } else {
                flushGroup()
                result.append(message)
            }
        }
        flushGroup()
        return result
    }

    /// 由一组「只含工具调用的助手消息」构造合成展示消息。
    ///
    /// - 平铺所有消息的 `toolCalls`（忽略来自哪条消息）。
    /// - 新 Turn 消息使用 `renderKind = "turn-activity"` 让渲染器识别活动行。
    /// - 没有 turnID 的历史消息继续使用 `"tool-step-group"`。
    /// - 复用首条消息的 id/conversationID/createdAt 等，保证合成消息在 ForEach diff
    ///   上稳定（组内成员不变 → id 不变）。
    private static func makeToolStepGroup(from messages: [Message]) -> Message {
        let head = messages.first
            ?? Message(conversationID: UUID(), role: .assistant, content: "")
        let allToolCalls = messages.flatMap { $0.toolCalls ?? [] }
        return Message(
            id: head.id,
            conversationID: head.conversationID,
            role: .assistant,
            content: head.content,
            createdAt: head.createdAt,
            turnID: head.turnID,
            metadata: head.metadata,
            isError: head.isError,
            providerID: head.providerID,
            modelName: head.modelName,
            renderKind: head.turnID == nil ? "tool-step-group" : "turn-activity",
            toolCalls: allToolCalls
        )
    }
}
