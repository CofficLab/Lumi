import Foundation
import KernelLumi

/// Message List Row Builder
///
/// 负责把"展示用的最终行序列"的合并规则收敛在视图模型层。
/// **纯数据库驱动**:输入只有真实落库消息(`persisted`,已由 `MessageManaging`
/// 合并了瞬时 status 行),不再拼接任何流式临时行。
///
/// status 行("正在思考…"等)始终保留显示 —— 它是流式期间唯一的进度反馈,
/// 由 `AgentTurn` 生命周期结束时清除,不在此处丢弃。
///
/// 此外,**V1 (brief)** 模式下会剔除独立的 `.tool` 结果行 —— 其结果收入助手消息内联的
/// 「可折叠工具步骤组」,避免重复展示;仅展示层过滤,持久化与 LLM 历史不受影响。
///
/// V1 还会把**连续多条**「只含工具调用的助手消息」(`isToolExecutionOnly`)合并成
/// **一条合成消息**(`renderKind == "tool-step-group"`),其 `toolCalls` 为各消息的平铺。
/// 这样它们在 UI 上呈现为一个整体(一个气泡 / 一个可折叠步骤组),而不是 N 个独立行。
/// 合成消息只在展示层生成,绝不落库、不进 LLM 历史。
///
/// - SeeAlso: `MessageListPaginationService`,负责真实消息的分页。
@MainActor
struct MessageListRowBuilder {
    /// 由真实落库消息(含 status)产出最终展示列表。纯数据库驱动,无流式临时行。
    ///
    /// - Parameters:
    ///   - persisted: 当前内存中真实落库的消息(已按时间升序,已含 `MessageManaging`
    ///     合并的瞬时 status 行)。
    ///   - conversationID: 当前会话;若为 `nil` 则直接返回真实消息(无会话 → 无需过滤)。
    ///   - verbosity: 当前会话的响应详细程度。V1 (brief) 下隐藏独立的 `.tool` 结果行
    ///     —— 其结果已收入助手消息内联的「可折叠工具步骤组」(展开后可查看);
    ///     这里仅做展示层过滤,不影响持久化与发送给 LLM 的历史。
    func build(
        persisted: [LumiChatMessage],
        conversationID: UUID?,
        verbosity: LumiResponseVerbosity
    ) -> [LumiChatMessage] {
        buildHistory(
            persisted: persisted,
            conversationID: conversationID,
            verbosity: verbosity
        )
    }

    /// 构建稳定的历史展示行。纯数据库驱动,不再随流式 token 重建 ——
    /// 仅在落库消息变化(新增/编辑/删除)或流式行可见性翻转(nil↔非 nil)时触发。
    ///
    /// - Parameter hidesStatus: 流式行可见时应丢弃历史里的 `.status` 行
    ///   ("正在思考…"等),否则会与流式行同时显示。流式行不可见时保留 status 行
    ///   作为进度反馈。可见性只取决于"有没有流式行",不取决于内容,故只需在
    ///   nil↔非 nil 切换时重算(由 viewmodel 控制),token 增长不触发。
    func buildHistory(
        persisted: [LumiChatMessage],
        conversationID: UUID?,
        verbosity: LumiResponseVerbosity,
        hidesStatus: Bool = false
    ) -> [LumiChatMessage] {
        guard let conversationID else { return persisted }

        let dropToolRows = verbosity == .brief
        let filtered = persisted.filter { message in
            if dropToolRows, message.role == .tool { return false }
            if hidesStatus, message.role == .status { return false }
            return true
        }

        return Self.mergeConsecutiveToolExecutionMessages(filtered)
    }

    /// 把同一 Turn 中连续的 `isToolExecutionOnly` 助手消息合并成一条活动消息。
    /// 新消息使用 `renderKind == "turn-activity"`;没有 turnID 的历史消息继续使用
    /// `"tool-step-group"`,保持旧数据的展示兼容。
    ///
    /// 单条此类消息也走合成路径(行为等价,仅多一个 renderKind 标记)。
    /// 合成消息复用组内首条消息的 id/conversationID/createdAt,保证稳定。
    private static func mergeConsecutiveToolExecutionMessages(
        _ messages: [LumiChatMessage]
    ) -> [LumiChatMessage] {
        var result: [LumiChatMessage] = []
        var currentGroup: [LumiChatMessage] = []
        var currentTurnID: UUID?
        var turnGroups: [UUID: [LumiChatMessage]] = [:]
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
    /// - 平铺所有消息的 `toolCalls`(忽略来自哪条消息)。
    /// - 新 Turn 消息使用 `renderKind = "turn-activity"` 让渲染器识别活动行。
    /// - 没有 turnID 的历史消息继续使用 `"tool-step-group"`。
    /// - 复用首条消息的 id/conversationID/createdAt 等,保证合成消息在 ForEach diff
    ///   与 `lumiActiveToolGroupIDs` 匹配上稳定(组内成员不变 → id 不变)。
    private static func makeToolStepGroup(from messages: [LumiChatMessage]) -> LumiChatMessage {
        let head = messages.first
            ?? LumiChatMessage(conversationID: UUID(), role: .assistant, content: "")
        let allToolCalls = messages.flatMap { $0.toolCalls ?? [] }
        return LumiChatMessage(
            id: head.id,
            conversationID: head.conversationID,
            role: .assistant,
            content: head.content,
            turnID: head.turnID,
            createdAt: head.createdAt,
            providerID: head.providerID,
            modelName: head.modelName,
            isError: head.isError,
            renderKind: head.turnID == nil ? "tool-step-group" : "turn-activity",
            metadata: head.metadata,
            toolCalls: allToolCalls
        )
    }
}
