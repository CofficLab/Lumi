import Foundation

/// 流式事件类型
enum StreamEventType: String, Sendable {
    case messageStart = "message_start"
    case messageDelta = "message_delta"
    case messageStop = "message_stop"
    case contentBlockStart = "content_block_start"
    case contentBlockDelta = "content_block_delta"
    case contentBlockStop = "content_block_stop"
    case thinkingDelta = "thinking_delta"
    case textDelta = "text_delta"
    case inputJsonDelta = "input_json_delta"
    case signatureDelta = "signature_delta"
    case ping
    case unknown

    // MARK: - UI

    /// 状态行、调试等使用的简短中文名（与 `rawValue` 协议名区分）
    var displayName: String {
        switch self {
        case .messageStart: return "消息开始"
        case .messageDelta: return "消息更新"
        case .messageStop: return "消息结束"
        case .contentBlockStart: return "内容块开始"
        case .contentBlockDelta: return "内容块更新"
        case .contentBlockStop: return "内容块结束"
        case .thinkingDelta: return "正在思考"
        case .textDelta: return "正在生成消息"
        case .inputJsonDelta: return "正在生成工具调用的参数"
        case .signatureDelta: return "签名"
        case .ping: return "心跳"
        case .unknown: return "未知事件"
        }
    }

    func isReceivingContent() -> Bool {
        self == .messageStart
            || self == .messageDelta
            || self == .messageStop
            || self == .contentBlockStart 
            || self == .contentBlockDelta
            || self == .contentBlockStop
            || self == .textDelta
            || self == .inputJsonDelta
            || self == .signatureDelta
            || self == .ping
    }

    func isThinking() -> Bool {
        self == .thinkingDelta
    }

    func isDone() -> Bool {
        self == .messageStop || self == .contentBlockStop
    }
}
