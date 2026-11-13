import Foundation
import ProviderMessage

/// 复刻自旧版 KernelLumi 的 `LumiChatMessage` 扩展（渲染层所需子集）。
/// 新版 `Message` 与旧版字段对齐，此处补上展示层依赖的派生属性。
public extension Message {
    /// 该助手消息是否「只用于报告工具执行、无实质回复」。
    /// 数据层用它把连续多条此类消息合并成一条 tool-step-group / turn-activity。
    var isToolExecutionOnly: Bool {
        guard role == .assistant else { return false }
        let hasToolCall = toolCalls?.isEmpty == false
        guard hasToolCall else { return false }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedContent.isEmpty || trimmedContent == "..."
    }

    /// 是否为「空响应」：无可见文本、无工具调用、非错误消息。
    var isEmptyResponse: Bool {
        guard !isError else { return false }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.isEmpty else { return false }
        let hasToolCalls = toolCalls?.isEmpty == false
        guard !hasToolCalls else { return false }
        return true
    }
}

/// 复刻自旧版 KernelLumi 的 `LumiChatMarkers`：消息正文中的特殊标记常量。
/// （渲染层 PluginMessageRenderer 内部也有同值常量，但为 internal，此处独立维护。）
public enum LumiChatMarkers {
    public static let turnCompleted = "__lumi_turn_completed__"
}

/// 流式临时行的进程级稳定 id。
/// 与落库消息的随机 UUID 永不冲突，落库时流式行消失 + 真实行出现被
/// SwiftUI 作为两次独立 diff 处理，无 id 交换、无闪烁。
public let LumiStreamingRowID = UUID()

/// 消息时间排序：先按 createdAt，再按 id 字符串，保证完全稳定。
public func messageOrdering(_ lhs: Message, _ rhs: Message) -> Bool {
    if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
    return lhs.createdAt < rhs.createdAt
}

public extension UUID {
    /// 稳定哈希值：跨进程一致（视图 identity、内容版本号专用）。
    var stableHashValue: Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        withUnsafeBytes(of: uuid) { rawBuffer in
            for byte in rawBuffer {
                hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
            }
        }
        return Int(bitPattern: UInt(hash & 0x7FFF_FFFF_FFFF_FFFF))
    }
}
