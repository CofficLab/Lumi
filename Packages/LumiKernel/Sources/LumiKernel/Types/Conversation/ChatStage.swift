import Foundation

/// 聊天回合的当前阶段。
///
/// 反映一轮对话从用户发送到 LLM 回复完成的进度，供 UI 展示阶段性状态文案
/// （如"正在发送消息…"/"正在思考…"/"正在生成回复…"）。由 `MessageStreaming`
/// 在流式生命周期中维护，与 `LumiTurnEndReason`（回合结束原因）互补——
/// 后者描述回合"为何结束"，本类型描述回合"进行到哪一步"。
public enum ChatStage: Sendable, Equatable {
    /// 无进行中的回合（空闲）。
    case idle
    /// 用户消息已落库，等待 LLM 首个响应（含工具调用回合之间的间隔）。
    case sending
    /// 正在接收 LLM 的思考（reasoning）增量。
    case thinking
    /// 正在接收 LLM 的正文增量。
    case generating
}
