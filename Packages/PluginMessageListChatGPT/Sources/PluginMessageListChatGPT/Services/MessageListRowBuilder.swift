import Foundation
import ProviderConversation
import ProviderMessage
import KitMessageList

/// V5（ChatGPT）消息行的合并规则。
///
/// **纯数据库驱动**：输入只有真实落库消息（`persisted`），
/// 不再拼接任何流式临时行。
///
/// 此外，这里**无条件剔除独立的 `.tool` 结果行**（对齐旧版行为：旧版分页在磁盘读取
/// 时就用 `includesToolMessages=false` 排除了 `.tool` 行，UI 从不展示工具结果消息）。
/// 工具信息仍通过助手消息内联的 toolCalls 呈现，避免重复展示。
///
/// 本 builder 还会把**连续多条**「只含工具调用的助手消息」（`isToolExecutionOnly`）合并成
/// **一条合成消息**（`renderKind == "tool-step-group"` / `"turn-activity"`），
/// 其 `toolCalls` 为各消息的平铺。
@MainActor
struct MessageListRowBuilder {
    /// 构建稳定的历史展示行。
    ///
    /// - Parameter hidesStatus: 流式行可见时应丢弃历史里的 `.status` 行
    ///   （"正在思考…"等），否则会与流式行同时显示。
    func buildHistory(
        persisted: [Message],
        conversationID: UUID?,
        verbosity: ResponseVerbosity,
        hidesStatus: Bool = false
    ) -> [Message] {
        guard conversationID != nil else { return persisted }

        // 无条件剔除独立的 .tool 结果行。
        let filtered = persisted.filter { message in
            if message.role == .tool { return false }
            if hidesStatus, message.role == .status { return false }
            return true
        }

        return Self.mergeConsecutiveToolExecutionMessages(filtered)
    }

    /// 把**时间上相邻**的 `isToolExecutionOnly` 助手消息合并成一条活动消息。
    ///
    /// - Important: 「相邻」指的是**时间上相邻**，而不是「同一个 turn」。
    ///
    ///   曾经的实现按 turnID 分桶：同一回合的所有工具消息无论中间隔着什么
    ///   都被并进一组。那会把跨越整段正文回复的两批工具执行合成一行，
    ///   而这一行锚定在**组首**（最早那条工具消息）的时间上 ——
    ///   真实后果是承载授权卡片的合成行被排到它本该包含的挂起点**之前**。
    ///
    ///   因此：任何**非**工具执行的消息都必须**终止**当前工具组，
    ///   工具组只合并时间上紧挨着的那些消息。
    ///
    /// - Important: 合成行的 `id` **必须随组内成员集合变化**。
    ///   若 id 恒等于首条消息的 id，组内新增成员时行身份不变，
    ///   SwiftUI 便认为这一行「没变」而**不重新物化**它 ——
    ///   新并入的挂起工具行（及其授权卡片）就画不出来。
    private static func mergeConsecutiveToolExecutionMessages(
        _ messages: [Message]
    ) -> [Message] {
        var result: [Message] = []
        var currentGroup: [Message] = []

        func flushGroup() {
            guard !currentGroup.isEmpty else { return }
            result.append(makeToolStepGroup(from: currentGroup))
            currentGroup = []
        }

        for message in messages {
            if message.isToolExecutionOnly {
                currentGroup.append(message)
            } else {
                // 非工具执行的消息（正文回复、用户消息等）**终止**当前工具组。
                flushGroup()
                result.append(message)
            }
        }
        flushGroup()
        return result
    }

    /// 由一组「只含工具调用的助手消息」构造合成展示消息。
    ///
    /// - 平铺所有消息的 `toolCalls`（忽略来自哪条消息）。
    /// - 有 turnID 时使用 `renderKind = "turn-activity"`，否则 `"tool-step-group"`。
    /// - 复用首条消息的 conversationID/createdAt 等，保证合成消息在 ForEach diff
    ///   上稳定（组内成员不变 → id 不变）。
    ///
    /// - Important: **组内成员按时间排序，时间锚点取组内最早成员。**
    ///   合成行代表整组工具执行，它的位置必须落在组内所有成员的覆盖区间内。
    ///   同样地，组内 `toolCalls` 必须按时间顺序平铺，
    ///   折叠摘要里的步骤顺序才与真实执行顺序一致。
    private static func makeToolStepGroup(from messages: [Message]) -> Message {
        // 组内按时间排序，时间相同按 id 稳定排序：同一组无论以何种顺序
        // 到达都得到同一个结果。
        let ordered = messages.sorted(by: messageOrdering)
        let head = ordered.first
            ?? Message(conversationID: UUID(), role: .assistant, content: "")
        let allToolCalls = ordered.flatMap { $0.toolCalls ?? [] }
        return Message(
            id: derivedGroupID(head: head, messages: ordered),
            conversationID: head.conversationID,
            role: .assistant,
            content: head.content,
            createdAt: head.createdAt,
            turnID: head.turnID,
            metadata: head.metadata,
            isError: head.isError,
            providerID: head.providerID,
            modelName: head.modelName,
            renderKind: head.turnID == nil ? "tool-step-group" : "turn-activity",
            toolCalls: allToolCalls
        )
    }

    /// 由组内成员 id 的集合派生合成行的稳定 id。
    ///
    /// - 成员集合不变时返回值恒定 ⇒ 行身份稳定，不触发整列表重新物化。
    /// - 成员集合变化时返回值改变 ⇒ 行身份变化，SwiftUI 重新物化该行，
    ///   新并入的挂起工具行（授权卡片）得以显示。
    ///
    /// - Note: 用成员 id 排序后拼接再做哈希，保证与消息的到达顺序无关 ——
    ///   同一组消息无论以什么顺序被扫到，都得到同一个 id。
    private static func derivedGroupID(head: Message, messages: [Message]) -> UUID {
        let memberIDs = messages.map { $0.id.uuidString }.sorted().joined(separator: "|")
        guard !memberIDs.isEmpty else { return head.id }
        // FNV-1a：只取低 64 位，避免字节移位溢出。
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in memberIDs.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: hash.bigEndian) { hashBytes in
            for index in 0..<8 {
                bytes[index] = hashBytes[index]
            }
        }
        withUnsafeBytes(of: head.id.uuid) { headBytes in
            for index in 0..<8 {
                bytes[8 + index] = headBytes[index]
            }
        }
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        // 兜底：确保与首条消息 id 不同（成员集合非空时必然不同）。
        return uuid == head.id ? UUID() : uuid
    }
}
