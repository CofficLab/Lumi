import Foundation
import LumiKernel

/// Message List Row Builder
///
/// 负责把"展示用的最终行序列"的合并规则收敛在视图模型层:
/// 真实落库消息(`persisted`,已由 `MessageManaging` 合并了瞬时 status 行)之后,
/// 按流式阶段决定是否拼接流式临时行、是否剔除 status 行。
///
/// 行合并规则(按流式阶段 `MessageStreaming.currentStage`):
/// - **`.sending`**(LLM 尚未响应):流式行是空壳不显示;只显示 status"正在发送…"。
/// - **`.thinking`**(思考中):显示流式行(渲染思考文本),剔除 status。
/// - **`.generating`**(正文生成中):显示流式行(渲染正文),剔除 status。
/// - **`.idle`**(无流式):不显示流式行;status 由 sender 生命周期管理(回合产物 insert 时清除)。
///
/// 即:status 只在 `.sending` 窗口显示,流式实质内容一来就退场。
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
    /// 拼接真实消息(含 status) + 流式临时行,产出最终展示列表。
    ///
    /// - Parameters:
    ///   - persisted: 当前内存中真实落库的消息(已按时间升序,已含 `MessageManaging`
    ///     合并的瞬时 status 行)。
    ///   - conversationID: 当前会话;若为 `nil` 则只返回真实消息(无会话 → 流式行无展示意义)。
    ///   - streaming: 流式服务 —— 读取临时行 + 当前阶段。可能为 `nil`(尚未就绪);
    ///     `nil` 等价于"无流式进行"。
    ///   - verbosity: 当前会话的响应详细程度。V1 (brief) 下隐藏独立的 `.tool` 结果行
    ///     —— 其结果已收入助手消息内联的「可折叠工具步骤组」(展开后可查看);
    ///     这里仅做展示层过滤,不影响持久化与发送给 LLM 的历史。
    func build(
        persisted: [LumiChatMessage],
        conversationID: UUID?,
        streaming: (any MessageStreaming)?,
        verbosity: LumiResponseVerbosity
    ) -> [LumiChatMessage] {
        guard let conversationID else { return persisted }

        let streamingRow = streaming?.currentStreamingRow
        let stage = streaming?.currentStage ?? .idle
        let belongsToCurrent = streamingRow?.conversationID == conversationID

        // 流式行显示条件:thinking(展示思考文本)或 generating(展示正文)阶段才显示。
        // .sending 阶段流式行是空壳(LLM 尚未响应),不显示 —— 该阶段由 status"正在发送…"承载。
        let showStreamingRow = belongsToCurrent
            && (stage == .thinking || stage == .generating)
            && streamingRow != nil

        // 流式行一旦实质展示(thinking/generating),status 就退场(由流式行承载)。
        // 仅 .sending 阶段保留 status。
        let dropStatus = showStreamingRow
        // V1 下隐藏独立 `.tool` 结果行(结果收进步骤卡片,避免与内联展示重复)。
        let dropToolRows = verbosity == .brief
        let filtered = persisted.filter { message in
            if dropStatus, message.role == .status { return false }
            if dropToolRows, message.role == .tool { return false }
            return true
        }

        // 把连续的「只含工具调用的助手消息」合并成一条合成消息。
        // V1 与 V2/V3 都合并:V1 走可折叠步骤组,V2/V3 走助手气泡(多个工具卡片聚在一起,
        // 只剩一个消息头)。合成消息仅在展示层,不落库、不进 LLM 历史。
        var rows = Self.mergeConsecutiveToolExecutionMessages(filtered)

        if showStreamingRow, let streamingRow {
            rows.append(streamingRow)
        }
        return rows
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

        func flushGroup() {
            guard !currentGroup.isEmpty else { return }
            result.append(makeToolStepGroup(from: currentGroup))
            currentGroup = []
            currentTurnID = nil
        }

        for message in messages {
            if message.isToolExecutionOnly {
                if !currentGroup.isEmpty, currentTurnID != message.turnID {
                    flushGroup()
                }
                currentGroup.append(message)
                currentTurnID = currentTurnID ?? message.turnID
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
