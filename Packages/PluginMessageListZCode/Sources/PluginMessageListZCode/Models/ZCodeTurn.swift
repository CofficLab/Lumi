import Foundation
import ProviderMessage

/// V4（ZCode）轮次投影的结果类型。
///
/// 纯值类型：只做 UI 投影，**不写回** `Message` / SwiftData。
struct ZCodeTurnRow: Identifiable, Equatable {
    /// 行的来源。
    enum Origin: Equatable {
        /// 落库历史行。
        case history
        /// 流式临时行。
        case streaming
        /// 会话活动行。
        case activity
    }

    /// 行身份：`history:<messageUUID>` / `streaming` / `conversation-activity`。
    let id: String
    /// 该行对应的消息。
    let message: Message
    /// 行来源。
    let origin: Origin
}

/// V4（ZCode）的一轮对话。
///
/// 一轮由「用户消息」开启，其后的助手正文、工作历史与状态行都归属这一轮；
/// 轮尾操作栏（复制与时间）挂在 `tailAssistantRowID` 指向的那一行上。
struct ZCodeTurn: Identifiable, Equatable {
    /// 轮次身份：`turn:<turnUUID>` 或 `message:<messageUUID>`。
    let id: String
    /// 真实存在的 agent 轮次 ID；旧数据可能为 nil。
    var agentTurnID: UUID?
    /// 本轮包含的行，按时间顺序。
    var rows: [ZCodeTurnRow]
    /// 本轮是否仍在运行中。
    var isRunning: Bool
    /// 轮尾助手正文的行 id；没有助手正文时为 nil。
    var tailAssistantRowID: String?
    /// 整轮复制文本（所有非空助手正文按 `\n\n` 连接）。
    var assistantCopyText: String
    /// 轮尾正文的真实完成时间；运行中为 nil。
    var completedAt: Date?
}

/// 一次投影的完整结果。
struct ZCodeTurnProjection: Equatable {
    /// 全部轮次（历史轮次 + live tail）。
    let turns: [ZCodeTurn]
    /// 仅历史轮次的数量。
    let historyTurnCount: Int
    /// 仅历史轮次的身份列表。
    let historyTurnIDs: [String]
}
