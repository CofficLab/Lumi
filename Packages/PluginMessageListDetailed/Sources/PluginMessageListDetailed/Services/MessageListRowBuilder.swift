import Foundation
import ProviderConversation
import ProviderMessage

/// Message List Row Builder
///
/// 负责把「展示用的最终行序列」的合并规则收敛在视图模型层。
/// **纯数据库驱动**：输入只有真实落库消息（`persisted`，已由 `MessageManaging`
/// 合并了瞬时 status 行），不再拼接任何流式临时行。
///
/// status 行（"正在思考…"等）始终保留显示 —— 它是流式期间唯一的进度反馈，
/// 由 `AgentTurn` 生命周期结束时清除，不在此处丢弃。
///
/// 此外，这里**无条件剔除独立的 `.tool` 结果行**（对齐旧版行为：旧版分页在磁盘读取
/// 时就用 `includesToolMessages=false` 排除了 `.tool` 行，UI 从不展示工具结果消息）。
/// 工具信息仍通过助手消息内联的 toolCalls（`tool-step-group` / `turn-activity`）呈现，
/// 避免重复展示；仅展示层过滤，持久化与 LLM 历史不受影响。
///
/// 本 builder 还会把**连续多条**「只含工具调用的助手消息」（`isToolExecutionOnly`）合并成
/// **一条合成消息**（`renderKind == "tool-step-group"`），其 `toolCalls` 为各消息的平铺。
/// 这样它们在 UI 上呈现为一个整体（一个气泡 / 一个可折叠步骤组），而不是 N 个独立行。
/// 合成消息只在展示层生成，绝不落库、不进 LLM 历史。
@MainActor
struct MessageListRowBuilder {
    func build(
        persisted: [Message],
        conversationID: UUID?,
        verbosity: ResponseVerbosity
    ) -> [Message] {
        buildHistory(
            persisted: persisted,
            conversationID: conversationID,
            verbosity: verbosity
        )
    }

    /// 构建稳定的历史展示行。纯数据库驱动，不再随流式 token 重建 ——
    /// 仅在落库消息变化（新增/编辑/删除）或流式行可见性翻转（nil↔非 nil）时触发。
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

        // 无条件剔除独立的 .tool 结果行（对齐旧版：旧版分页在磁盘读取时即
        // 用 includesToolMessages=false 排除 .tool 行，UI 从不展示工具结果消息）。
        // 工具信息由助手消息内联的 toolCalls（tool-step-group / turn-activity）呈现。
        let filtered = persisted.filter { message in
            if message.role == .tool { return false }
            if hidesStatus, message.role == .status { return false }
            return true
        }

        return Self.mergeConsecutiveToolExecutionMessages(filtered)
    }

    /// 把**时间上相邻**的 `isToolExecutionOnly` 助手消息合并成一条活动消息。
    /// 新消息使用 `renderKind == "turn-activity"`；没有 turnID 的历史消息继续使用
    /// `"tool-step-group"`，保持旧数据的展示兼容。
    ///
    /// 单条此类消息也走合成路径（行为等价，仅多一个 renderKind 标记）。
    /// 合成消息复用组内首条消息的 id/conversationID，保证稳定。
    ///
    /// - Important: 「相邻」指的是**时间上相邻**，而不是「同一个 turn」。
    ///
    ///   曾经的实现按 turnID 分桶：同一回合的所有工具消息无论中间隔着什么
    ///   都被并进一组。那会把跨越整段正文回复的两批工具执行合成一行，
    ///   而这一行锚定在**组首**（最早那条工具消息）的时间上。
    ///
    ///   真实后果（2026-11-03 08:35，会话 E709F960）：回合里 08:29:43~08:29:56
    ///   的工具消息与 08:34:05~08:35:09 的工具消息被并成一行，其中最后一条
    ///   是等待用户授权的挂起点。合成行落在 08:29:43，于是 08:30 的正文回复
    ///   被渲染到授权卡片**下方**——用户看到「授权后没暂停，继续往下跑」，
    ///   而回合其实早已 suspended。
    ///
    ///   因此：任何**非**工具执行的消息都必须**终止**当前工具组，
    ///   工具组只合并时间上紧挨着的那些消息。
    ///
    /// - Note: 工具组内允许跨 turnID 合并。相邻两批工具消息即使属于不同
    ///   回合（如恢复回合后的第一批），只要在时间上紧挨着，合并成一行也更
    ///   符合「一串工具执行」的视觉语义。组内成员按时间排序，时间相同按 id
    ///   稳定排序，保证同一组无论以何种顺序到达都得到同一个结果。
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
    /// - 新 Turn 消息使用 `renderKind = "turn-activity"` 让渲染器识别活动行。
    /// - 没有 turnID 的历史消息继续使用 `"tool-step-group"`。
    /// - 复用首条消息的 conversationID/createdAt 等，保证合成消息在 ForEach diff
    ///   上稳定（组内成员不变 → id 不变）。
    ///
    /// - Important: **`id` 必须随组内成员集合变化。**
    ///   V3 列表用 `ForEach(historyRows)` + `.id(message.id)` 作为行的身份。
    ///   若 id 恒等于首条消息的 id，组内新增成员时行身份不变，SwiftUI 便认为
    ///   这一行「没变」而**不重新物化**它 —— 新并入的挂起工具行（及其授权卡片）
    ///   就画不出来，用户看到的是底部挂着「等待你的输入…」，却找不到任何可回答的卡片。
    ///   （真实案例：2026-10-31 08:40:15，`accessibility_observe` 对 Dock 的授权请求
    ///   并入已有工具组后，授权卡片始终没有出现。）
    ///
    ///   因此这里用**成员 id 的集合**派生一个确定性 UUID：成员集合不变 → id 不变
    ///   （不触发无谓的整列表重新物化），成员集合变化 → id 变化（强制重新物化）。
    ///
    /// - Important: **组内成员按时间排序，时间锚点取组内最早成员。**
    ///
    ///   合成行代表整组工具执行，它的位置必须落在组内所有成员的覆盖区间内。
    ///   若沿用「首条成员」的时间，而首条并非时间最早的那条（例如分页回填
    ///   或乱序插入），合成行就会被锚定到一个错误的位置——排在它本该包含的
    ///   挂起点**之前**，于是承载的授权卡片出现在旧内容上方。
    ///
    ///   同样地，组内 `toolCalls` 必须按时间顺序平铺，折叠摘要里的步骤顺序
    ///   才与真实执行顺序一致。
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
