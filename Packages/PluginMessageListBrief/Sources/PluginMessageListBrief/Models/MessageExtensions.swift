import Foundation
import ProviderMessage

/// 复刻自旧版 KernelLumi 的 `LumiChatMessage` 扩展（渲染层所需子集）。
/// 新版 `Message` 与旧版字段对齐，此处补上展示层依赖的派生属性。
extension Message {
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

/// 消息时间排序：先按 createdAt，再按 id 字符串，保证完全稳定。
func messageOrdering(_ lhs: Message, _ rhs: Message) -> Bool {
    if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
    return lhs.createdAt < rhs.createdAt
}

extension UUID {
    /// 稳定哈希值：跨进程一致。
    ///
    /// - Important: 不要用 `String.hashValue` 或 `UUID.hashValue` ——
    ///   它们的种子**每个进程启动都会变**，同一条消息在不同进程里会得到
    ///   不同的哈希值。凡是用来做视图 identity、内容版本号的地方，
    ///   都需要这种跨进程稳定的哈希。
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
