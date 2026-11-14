import Foundation
import KitAgentTool

/// 工具授权请求（渲染层视图模型）。
///
/// - Note: 载荷的编解码由 `KitAgentTool.ToolInteractionPayload` 负责——
///   它是这份跨层契约的唯一归属。渲染层只做「展示」与「决定」，不再
///   自己定义一份副本（历史上这里有一份副本，且键名与生产者不一致，
///   导致授权载荷解码必然失败）。
struct ToolPermissionRequest {
    let toolCallID: String
    let kind: String
    let question: String
    let options: [String]
    let mode: String

    init(
        toolCallID: String,
        kind: String,
        question: String,
        options: [String],
        mode: String
    ) {
        self.toolCallID = toolCallID
        self.kind = kind
        self.question = question
        self.options = options
        self.mode = mode
    }

    /// 从工具结果内容里解析授权请求。
    init?(payload: ToolInteractionPayload) {
        self.init(
            toolCallID: payload.toolCallID,
            kind: payload.kind,
            question: payload.question,
            options: payload.options,
            mode: payload.mode
        )
    }

    /// 从工具结果内容里解析授权请求。
    ///
    /// - Returns: 载荷确实是**通用工具授权**请求时返回该请求；否则 `nil`。
    ///
    /// - Note: Computer Use 的应用授权载荷（`kind == "computer_use_authorization"`）
    ///   不属于此类——它由 Computer Use 自己的渲染器接管。
    static func decode(from content: String) -> ToolPermissionRequest? {
        guard let payload = ToolInteractionPayload.decodePermission(from: content) else {
            return nil
        }
        return ToolPermissionRequest(payload: payload)
    }
}
