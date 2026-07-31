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
    func build(
        persisted: [LumiChatMessage],
        conversationID: UUID?,
        streaming: (any MessageStreaming)?
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
        var rows = dropStatus
            ? persisted.filter { $0.role != .status }
            : persisted

        if showStreamingRow, let streamingRow {
            rows.append(streamingRow)
        }
        return rows
    }
}
