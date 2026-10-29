#if DEBUG
import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// PluginMessageListBrief 的 UI 测试夹具（仅 DEBUG）。
///
/// 当 App 以 `--lumi-ui-testing-message-list-brief` 启动时，本夹具在 Chat
/// 会话里植入**一个** brief 模式确定性子会话 + 4 条预先构造好的 turns，
/// 用于无 LLM/无网络地驱动 `LumiMessageListBriefUITests`。
///
/// ## 夹具结构
///
/// 每个 turn 暴露成「用户消息 + 一个 assistant 工具调用 + 一个最终回复」三行，
/// 模拟真实 AgentTurn 投影；最后一条 turn 末尾留一个长 assistant 文本，方便
/// UI 测试验证「最后一行确实渲染到了视口底部」。
///
/// 启动参数：
/// - `--lumi-ui-testing-message-list-brief`：启用本夹具。
/// - `--lumi-ui-testing-isolated-storage`：建议同时启用，避免污染用户数据。
///
/// 范式参照 `ErrorRetryUITestingSupport`（PluginAgentLoop 失败回合夹具）：
/// 必须等 `ConversationManaging.loadConversations()` 完成后再 seed，
/// 否则 `loadConversations` 会把刚刚植入的会话覆盖。
@MainActor
public enum MessageListBriefUITestingSupport {
    /// 启用本夹具的启动参数。
    public static let launchArgument = "--lumi-ui-testing-message-list-brief"

    /// 夹具会话标题。
    public static let conversationTitle = "Message List Brief UI Testing"

    /// 强制 verbosity = brief（README §1 要求的「Response Detail = L (Brief)」）。
    public static let verbosity: ResponseVerbosity = .brief

    /// 植入的 4 个 turn 起始时间（基准时间）。
    private static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// 在 `MessageManaging` 与 `ConversationManaging` 上植入 brief 模式夹具。
    ///
    /// 与 `ErrorRetryUITestingSupport` 一致，必须等 `loadConversations()` 完
    /// 成后再 seed。`loadConversations` 会整体替换会话列表并清空选中态；
    /// 若过早植入，夹具会话会被这次加载覆盖。
    ///
    /// - Important: 观察者必须**一次性自取消**。seed 自身的 `insertMessage`
    ///   会经消息去抖触发 `.listChanged`；若不取消，seed → insert →
    ///   listChanged → seed 形成无限循环（曾单次启动创建 360+ 个会话）。
    ///
    /// - Returns: 一次性观察者句柄，插件 `onShutdown` 时调用 `cancel()` 释放。
    @discardableResult
    static func seed(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: (any AgentLoopProviding)? = nil
    ) -> any ConversationObserverHandle {
        guard !hasSeeded(conversations: conversations) else {
            return NoopObserverHandle()
        }
        if !conversations.isLoadingConversations {
            doSeed(conversations: conversations, messages: messages, agentLoop: agentLoop)
            return NoopObserverHandle()
        }
        let box = OneShotObserverBox()
        let handle = conversations.addConversationObserver { event in
            guard event == .listChanged else { return }
            // 一次性：先注销自己，再 seed（seed 会再次触发 listChanged）。
            box.handle?.cancel()
            box.handle = nil
            doSeed(conversations: conversations, messages: messages, agentLoop: agentLoop)
        }
        box.handle = handle
        return handle
    }

    /// 是否已存在夹具会话（防止同一进程内重复 seed）。
    private static func hasSeeded(conversations: any ConversationManaging) -> Bool {
        conversations.conversations.contains { $0.title == conversationTitle }
    }

    private static func doSeed(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: (any AgentLoopProviding)?
    ) {
        guard let conversationID = try? conversations.createConversation(
            title: conversationTitle,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        ) else { return }

        // 必须抑制自动回复：下面插入的 user 消息会被
        // `PluginAgentLoop.MessageObserver` 捕获并自动 `runTurn`。
        // 自动回合会写回一条 `createdAt = now` 的助手消息，把该会话的
        // `lastMessageAt` 推到「现在」，让会话列表的排序由竞态决定。
        //
        // 范式参照 `PluginAgentLoop.ErrorRetryUITestingSupport`：它同样是因为
        // 插入 user 消息而必须显式抑制自动回复。
        agentLoop?.setAutoReplySuppressed(true, for: conversationID)

        // 4 个 turn，全部保持简短：总高度低于消息区视口，避免 macOS List
        // 懒加载把视口外的行裁掉导致 UI 测试找不到元素。
        // 「3 步工具 turn」放在最后（视口锚定在底部时必然可见）。
        let turn1User = makeMessage(
            id: "11111111-1111-1111-1111-111111111111",
            conversationID: conversationID,
            role: .user,
            content: "请帮我总结这段代码",
            createdAt: baseDate,
            turnID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1"
        )
        let turn1Final = makeMessage(
            id: "11111111-2222-2222-2222-111111111111",
            conversationID: conversationID,
            role: .assistant,
            content: "已生成总结。",
            createdAt: baseDate.addingTimeInterval(2),
            turnID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1"
        )
        messages.insertMessage(turn1User, to: conversationID)
        messages.insertMessage(turn1Final, to: conversationID)

        let turn2User = makeMessage(
            id: "22222222-1111-1111-1111-111111111111",
            conversationID: conversationID,
            role: .user,
            content: "再来一个 turn",
            createdAt: baseDate.addingTimeInterval(10),
            turnID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2"
        )
        let turn2Final = makeMessage(
            id: "22222222-2222-2222-2222-111111111111",
            conversationID: conversationID,
            role: .assistant,
            content: "第二个 turn 的回复。",
            createdAt: baseDate.addingTimeInterval(12),
            turnID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2"
        )
        messages.insertMessage(turn2User, to: conversationID)
        messages.insertMessage(turn2Final, to: conversationID)

        let turn3User = makeMessage(
            id: "33333333-1111-1111-1111-111111111111",
            conversationID: conversationID,
            role: .user,
            content: "最后一个普通 turn",
            createdAt: baseDate.addingTimeInterval(20),
            turnID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3"
        )
        let turn3Final = makeMessage(
            id: "33333333-2222-2222-2222-111111111111",
            conversationID: conversationID,
            role: .assistant,
            content: "第三个 turn 的回复。",
            createdAt: baseDate.addingTimeInterval(22),
            turnID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3"
        )
        messages.insertMessage(turn3User, to: conversationID)
        messages.insertMessage(turn3Final, to: conversationID)

        // 最后一个 turn：3 个工具调用，便于 UI 测试断言 §3.2「执行了3个步骤」。
        // 放在列表末尾 —— 初始定位在底部时必然在视口内。
        let turn4ID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4"
        let turn4User = makeMessage(
            id: "44444444-1111-1111-1111-111111111111",
            conversationID: conversationID,
            role: .user,
            content: "执行三步操作",
            createdAt: baseDate.addingTimeInterval(30),
            turnID: turn4ID
        )
        let turn4Assistant = makeMessage(
            id: "44444444-2222-2222-2222-111111111111",
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: baseDate.addingTimeInterval(31),
            turnID: turn4ID,
            toolCalls: (0..<3).map { idx in
                MessageToolCall(
                    id: "c3-\(idx)",
                    name: "search",
                    arguments: "{}",
                    displayDescription: "步骤 \(idx + 1) — 查找项目文件"
                )
            }
        )
        let turn4Final = makeMessage(
            id: "44444444-3333-3333-3333-111111111111",
            conversationID: conversationID,
            role: .assistant,
            content: "三步全部完成。",
            createdAt: baseDate.addingTimeInterval(35),
            turnID: turn4ID
        )
        messages.insertMessage(turn4User, to: conversationID)
        messages.insertMessage(turn4Assistant, to: conversationID)
        messages.insertMessage(turn4Final, to: conversationID)

        // 显式选回夹具会话 + 设 brief 详细度，触发 ListV1View 注册。
        conversations.selectConversation(id: conversationID)
        conversations.setVerbosity(verbosity, for: conversationID)
    }

    private static func makeMessage(
        id: String,
        conversationID: UUID,
        role: MessageRole,
        content: String,
        createdAt: Date,
        turnID: String? = nil,
        toolCalls: [MessageToolCall]? = nil
    ) -> Message {
        Message(
            id: UUID(uuidString: id) ?? UUID(),
            conversationID: conversationID,
            role: role,
            content: content,
            createdAt: createdAt,
            turnID: turnID.map { UUID(uuidString: $0) ?? UUID() },
            toolCalls: toolCalls
        )
    }
}

/// 不需要清理的句柄占位。
@MainActor
private final class NoopObserverHandle: ConversationObserverHandle {
    func cancel() {}
}

/// 让一次性观察者闭包能引用到自己的注销句柄（自取消语义，
/// 与 `ErrorRetryUITestingSupport` 的 `ObserverHandleBox` 同范式）。
@MainActor
private final class OneShotObserverBox {
    var handle: (any ConversationObserverHandle)?
}
#endif
