import Foundation
import LumiKernel

/// Message Timeline Row Builder
///
/// 负责把"展示用的最终行序列"的合并规则收敛在数据层:
/// 在真实落库消息(`persisted`)之后,根据流式阶段 / 发送中状态拼接两类
/// **不写库**的临时行 —— 真实消息的分页、合并、裁剪逻辑只基于真实消息,
/// 临时行不会污染真实分页状态(因为它们使用稳定常量 id 与真实行永不冲突)。
///
/// 行合并规则(沉淀自原 `MessageListPlugin.MessageListRowBuilder`):
/// 1. 流式临时行(来自 `MessageStreaming.currentStreamingRow`)—
///    仅当 `conversationID` 匹配当前会话。切会话时该临时行会被自动过滤,
///    无需额外清理。
/// 2. 状态行(来自 `MessageSending.currentStatusRow(for:)`)显示条件:
///    - 没有流式行(发送阶段);或
///    - 处于 `thinking` 阶段(流式行的正文为空,思考文本走状态行展示)。
///    正文生成阶段(`generating`)由流式行承载,不叠加状态行。
///
/// - SeeAlso: `MessageTimelinePaginationService`,负责真实消息的分页。
@MainActor
struct MessageTimelineRowBuilder {
    /// 拼接真实消息 + 流式临时行 + 发送中状态行,产出最终展示列表。
    ///
    /// - Parameters:
    ///   - persisted: 当前内存中真实落库的消息(已按时间升序)。
    ///   - conversationID: 当前会话;若为 `nil` 则只返回真实消息
    ///     (无会话 → 临时行无展示意义)。
    ///   - sender: 发送服务 —— 仅当需要构造状态行时被调用。
    ///   - streaming: 流式服务 —— 读取临时行 + 当前阶段。可能为 `nil`
    ///     (尚未就绪);`nil` 等价于"无流式进行"。
    func build(
        persisted: [LumiChatMessage],
        conversationID: UUID?,
        sender: (any MessageSending)?,
        streaming: (any MessageStreaming)?
    ) -> [LumiChatMessage] {
        guard let conversationID else { return persisted }
        var rows = persisted

        // 1) 流式临时行(仅当属于当前会话;切会话时自动被过滤)。
        let streamingRow = streaming?.currentStreamingRow
        if let streamingRow, streamingRow.conversationID == conversationID {
            rows.append(streamingRow)
        }

        // 2) 状态行:仅在"无流式行"或"思考阶段正文为空"时显示
        //    正文生成阶段(`generating`)由流式行承载,不叠加状态行。
        let stage = streaming?.currentStage ?? .idle
        let belongsToCurrent: Bool = streamingRow?.conversationID == conversationID
        let showStatus = streamingRow == nil
            || (belongsToCurrent && stage == .thinking)
        if showStatus, let statusRow = sender?.currentStatusRow(for: conversationID) {
            rows.append(statusRow)
        }
        return rows
    }
}
