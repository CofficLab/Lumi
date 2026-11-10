import Foundation
import ProviderMessage

/// V4（ZCode）轮次投影器。
///
/// 输入是 `ListV4ViewModel.historyRows`（已含 `.tool` 行过滤与连续 tool-only 合并），
/// 因此**独立 `.tool` 过滤与连续工具合并只有一份事实来源**，投影不再重复这两件事。
///
/// 投影只产出 UI 值类型，**不写回** `Message` / SwiftData，
/// 也不修改 `MessageListRowBuilder` 的相邻工具合并规则。
///
/// - Important: 身份必须是**确定性**的：同一个输入重复投影得到完全相同的
///   turn / row id。禁止随机 UUID，否则 SwiftUI 会把每一帧都当成新行重新物化。
enum ZCodeTurnProjector {

    // MARK: - 公开入口

    /// 把历史行投影成轮次。
    static func project(_ history: [Message]) -> [ZCodeTurn] {
        buildTurns(from: history)
    }

    /// 把历史行 + live tail 投影成完整快照。
    ///
    /// - Parameters:
    ///   - history: 稳定历史展示行。
    ///   - streaming: 流式临时行；存在时不再插入活动行（保持 V3 的尾行规则）。
    ///   - activity: 会话活动行。
    static func project(
        history: [Message],
        streaming: Message?,
        activity: Message?
    ) -> ZCodeTurnProjection {
        var turns = buildTurns(from: history)

        // Live tail：流式存在时优先，且不与活动行并存。
        if let streaming {
            turns.append(buildLiveTurn(from: streaming, origin: .streaming))
        } else if let activity {
            turns.append(buildLiveTurn(from: activity, origin: .activity))
        }

        let historyTurnIDs = turns
            .prefix(while: { $0.rows.allSatisfy { $0.origin == .history } })
            .map(\.id)

        return ZCodeTurnProjection(
            turns: turns,
            historyTurnCount: historyTurnIDs.count,
            historyTurnIDs: historyTurnIDs
        )
    }

    // MARK: - 历史轮次

    /// 把历史行按轮次边界分组。
    ///
    /// 规则（计划 3.3 节）：
    /// 1. 用户消息开启新 turn。
    /// 2. 非用户行优先沿用当前 turn；若它和当前 turn 都有非 nil 且不同的 `turnID`，开启新 turn。
    /// 3. 当前 turn 尚无 `agentTurnID` 时，可由后续真实消息的非 nil `turnID` 补上。
    /// 4. 旧数据全部 nil turnID 时，以用户消息边界和原始顺序确定性分组。
    private static func buildTurns(from history: [Message]) -> [ZCodeTurn] {
        var turns: [ZCodeTurn] = []
        var currentRows: [ZCodeTurnRow] = []
        var currentTurnID: UUID?
        var currentUserMessageID: UUID?
        var currentAgentTurnID: UUID?

        for message in history {
            let isUser = message.role == .user

            // 规则 1：用户消息开启新 turn。
            if isUser {
                appendCurrentTurn(&turns, rows: currentRows, agentTurnID: currentAgentTurnID, userMessageID: currentUserMessageID)
                currentRows = []
                currentTurnID = message.turnID
                currentUserMessageID = message.id
                currentAgentTurnID = message.turnID
                currentRows.append(ZCodeTurnRow(id: historyRowID(message), message: message, origin: .history))
                continue
            }

            // 规则 2：非用户行沿用当前 turn；turnID 冲突则开启新 turn。
            if let messageTurnID = message.turnID,
               let existingTurnID = currentTurnID,
               existingTurnID != messageTurnID {
                appendCurrentTurn(&turns, rows: currentRows, agentTurnID: currentAgentTurnID, userMessageID: currentUserMessageID)
                currentRows = []
                currentTurnID = messageTurnID
                currentAgentTurnID = messageTurnID
            } else if currentTurnID == nil, let messageTurnID = message.turnID {
                // 当前 turn 尚无 turnID，但当前行有：沿用当前 turn 并补齐身份。
                currentTurnID = messageTurnID
                if currentAgentTurnID == nil {
                    currentAgentTurnID = messageTurnID
                }
            }

            // 规则 3：当前 turn 尚无 agentTurnID 时，由后续真实消息补齐。
            if currentAgentTurnID == nil, let messageTurnID = message.turnID {
                currentAgentTurnID = messageTurnID
            }

            currentRows.append(ZCodeTurnRow(id: historyRowID(message), message: message, origin: .history))
        }

        // 收集结束后结算最后一轮。
        if !currentRows.isEmpty {
            turns.append(
                makeTurn(
                    rows: currentRows,
                    agentTurnID: currentAgentTurnID,
                    userMessageID: currentUserMessageID
                )
            )
        }
        return turns
    }

    /// 把当前收集到的行结算成一个轮次；没有行时不产生空轮次。
    private static func appendCurrentTurn(
        _ turns: inout [ZCodeTurn],
        rows: [ZCodeTurnRow],
        agentTurnID: UUID?,
        userMessageID: UUID?
    ) {
        guard !rows.isEmpty else { return }
        turns.append(
            makeTurn(rows: rows, agentTurnID: agentTurnID, userMessageID: userMessageID)
        )
    }

    /// 由已收集的行构造一个轮次，并计算轮尾正文与整轮复制文本。
    private static func makeTurn(
        rows: [ZCodeTurnRow],
        agentTurnID: UUID?,
        userMessageID: UUID?
    ) -> ZCodeTurn {
        // 规则 8：只拼接 role == .assistant、非 tool-execution-only、去空白后非空的正文。
        let bodyRows = rows.filter { row in
            row.message.role == .assistant && !row.message.isToolExecutionOnly
        }
        let bodyTexts = bodyRows
            .map { $0.message.content.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 规则 9：轮尾正文是最后一个符合条件的正文行。
        let tailRowID = bodyRows.last?.id

        // 规则 10：完成时间取轮尾正文的真实 createdAt。
        let completedAt = bodyRows.last?.message.createdAt

        // 规则 6：含用户消息的轮次用 message:<userUUID>；
        // 助手/工作主导的轮次优先 turn:<turnUUID>，否则 message:<firstMessageUUID>。
        let id: String
        if let userMessageID {
            id = "message:\(userMessageID.uuidString)"
        } else if let agentTurnID {
            id = "turn:\(agentTurnID.uuidString)"
        } else if let first = rows.first {
            id = "message:\(first.message.id.uuidString)"
        } else {
            id = "message:empty"
        }

        return ZCodeTurn(
            id: id,
            agentTurnID: agentTurnID,
            rows: rows,
            isRunning: false,
            tailAssistantRowID: tailRowID,
            assistantCopyText: bodyTexts.joined(separator: "\n\n"),
            completedAt: completedAt
        )
    }

    // MARK: - Live tail

    /// 构造流式 / 活动尾行所属的轮次。
    ///
    /// - Important: 流式尾行属于**独立**的一轮，不并入历史轮次。
    ///   否则流式每个 token 都会改动历史轮次的身份，导致整段历史反复重绘。
    private static func buildLiveTurn(from message: Message, origin: ZCodeTurnRow.Origin) -> ZCodeTurn {
        let rowID: String
        switch origin {
        case .history: rowID = historyRowID(message)
        case .streaming: rowID = "streaming"
        case .activity: rowID = "conversation-activity"
        }

        let row = ZCodeTurnRow(id: rowID, message: message, origin: origin)
        let isAssistantBody = message.role == .assistant && !message.isToolExecutionOnly
        let body = isAssistantBody
            ? message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        let turnID: String
        if let agentTurnID = message.turnID {
            turnID = "turn:\(agentTurnID.uuidString)"
        } else {
            turnID = "message:\(message.id.uuidString)"
        }

        return ZCodeTurn(
            id: turnID,
            agentTurnID: message.turnID,
            rows: [row],
            isRunning: origin == .streaming,
            tailAssistantRowID: isAssistantBody && !body.isEmpty ? rowID : nil,
            assistantCopyText: body,
            completedAt: origin == .streaming ? nil : message.createdAt
        )
    }

    // MARK: - 身份

    /// 规则 7：history 行 id 固定为 `history:<messageUUID>`。
    private static func historyRowID(_ message: Message) -> String {
        "history:\(message.id.uuidString)"
    }
}
