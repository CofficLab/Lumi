#if DEBUG
import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// PluginMessageListStandard（V2 / 标准模式）的 UI 测试夹具（仅 DEBUG）。
///
/// 植入**多个**规模差异明显的子会话，用于验证「切换会话时首屏遮罩必须及时
/// 消失」——这正是用户报告的 10 秒卡死场景。
///
/// ## 为什么要多个会话
///
/// 遮罩显示条件是 `isLoading || !isInitialPositionReady`：
/// - `isLoading` 只等数据落库（实测毫秒级）；
/// - `isInitialPositionReady` 等首屏**定位收敛**。
///
/// 只有真正发生「切换」才能走通后一条路径，因此夹具必须提供多个可选会话。
/// 同时用不同体量制造难度差异：
/// - `Conversation Switch Small`（3 轮）：几何很快收敛；
/// - `Conversation Switch Large`（40 轮 + 富文本/代码块）：几何持续增长，
///   是最容易触发收敛不收敛、进而把遮罩挂住的场景。
///
/// ## 启动参数
/// - `--lumi-ui-testing-message-list-standard`：启用本夹具。
/// - `--lumi-ui-testing-isolated-storage`：建议同时启用，避免污染用户数据。
///
/// 范式参照 `MessageListBriefUITestingSupport`：必须等
/// `loadConversations()` 完成后再 seed，否则会被整表加载覆盖。
@MainActor
public enum MessageListStandardUITestingSupport {
    public static let launchArgument = "--lumi-ui-testing-message-list-standard"

    /// 小会话标题（易收敛）。
    public static let smallConversationTitle = "Switch Target Small"
    /// 大会话标题（几何持续增长，最易挂住遮罩）。
    public static let largeConversationTitle = "Switch Target Large"
    /// 超大会话标题（大数据量场景专用，见 `LumiMessageListScaleUITests`）。
    ///
    /// 与 `largeConversationTitle` 的区别：large 只有 40 轮，用来压「几何收敛」；
    /// 本会话体量大得多，用来压「数据量」——翻页、窗口裁剪、消息缺口等
    /// 只在消息数远超分页窗口时才会暴露的缺陷。
    public static let hugeConversationTitle = "Scale Target Huge"

    /// 工具调用组会话标题（验证「多工具调用折叠为一行摘要」）。
    ///
    /// 该会话里的助手消息都**只含工具调用**（正文为空），因此会被数据层
    /// 合并成 `turn-activity` 合成消息，渲染层再折叠成一行摘要。
    public static let toolGroupConversationTitle = "Tool Group Target"

    private static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// 大会话的 turn 数。足够让 List 懒加载多帧，逼近收敛上限。
    private static let largeTurnCount = 40
    /// 超大会话的 turn 数。
    ///
    /// 600 轮 = 1200 条消息，是 `pageSize(40)` 的 30 倍、`maxRetainedCount(300)`
    /// 的 4 倍。窗口上限与「永久缺口」缺陷都要到这个量级才会显形：
    /// 翻 10 页（400 条）即触发裁剪，缺口随即出现。
    private static let hugeTurnCount = 600

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

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

    private static func hasSeeded(conversations: any ConversationManaging) -> Bool {
        conversations.conversations.contains { $0.title == smallConversationTitle }
    }

    private static func doSeed(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: (any AgentLoopProviding)?
    ) {
        guard let small = try? conversations.createConversation(
            title: smallConversationTitle,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        ) else { return }
        guard let large = try? conversations.createConversation(
            title: largeConversationTitle,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        ) else { return }
        guard let huge = try? conversations.createConversation(
            title: hugeConversationTitle,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        ) else { return }
        guard let toolGroup = try? conversations.createConversation(
            title: toolGroupConversationTitle,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        ) else { return }

        // 必须抑制自动回复：下面每个会话都会插入 user 消息，而
        // `PluginAgentLoop.MessageObserver` 会对 user 消息自动 `runTurn`。
        // 自动回合会写回一条 `createdAt = now` 的助手消息，把该会话的
        // `lastMessageAt` 推到「现在」——四个会话的自动回复完成时刻各不相同，
        // 于是会话列表的排序由这场竞态决定，run-to-run 不稳定
        // （实测同一夹具两次运行的顺序不同）。
        //
        // 范式参照 `PluginAgentLoop.ErrorRetryUITestingSupport`：它同样是因为
        // 插入 user 消息而必须显式抑制自动回复。
        for conversationID in [small, large, huge, toolGroup] {
            agentLoop?.setAutoReplySuppressed(true, for: conversationID)
        }

        seedSmall(conversations: conversations, messages: messages, conversationID: small)
        seedLarge(conversations: conversations, messages: messages, conversationID: large)
        seedHuge(conversations: conversations, messages: messages, conversationID: huge)
        seedToolGroup(conversations: conversations, messages: messages, conversationID: toolGroup)

        // 选中大会话：它是更难收敛的一侧，作为 UI 测试的起始态。
        conversations.selectConversation(id: large)
        conversations.setVerbosity(.standard, for: large)
        // 超大会话同样按 standard 详细程度，否则 V2 列表槽位不会激活。
        conversations.setVerbosity(.standard, for: huge)
    }

    /// 小会话：3 轮，几何很快稳定。
    private static func seedSmall(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        conversationID: UUID
    ) {
        for index in 0..<3 {
            let turnID = UUID()
            messages.insertMessage(
                message(
                    conversationID: conversationID,
                    role: .user,
                    content: "小会话问题 \(index + 1)",
                    createdAt: baseDate.addingTimeInterval(Double(index) * 10),
                    turnID: turnID
                ),
                to: conversationID
            )
            messages.insertMessage(
                message(
                    conversationID: conversationID,
                    role: .assistant,
                    content: "小会话回答 \(index + 1)",
                    createdAt: baseDate.addingTimeInterval(Double(index) * 10 + 2),
                    turnID: turnID
                ),
                to: conversationID
            )
        }
    }

    /// 大会话：40 轮，含 Markdown 标题与代码块，制造持续增长的文档几何。
    private static func seedLarge(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        conversationID: UUID
    ) {
        for index in 0..<largeTurnCount {
            let turnID = UUID()
            let offset = Double(index) * 10
            messages.insertMessage(
                message(
                    conversationID: conversationID,
                    role: .user,
                    content: "大会话问题 \(index + 1)",
                    createdAt: baseDate.addingTimeInterval(offset),
                    turnID: turnID
                ),
                to: conversationID
            )
            messages.insertMessage(
                message(
                    conversationID: conversationID,
                    role: .assistant,
                    content: largeAssistantBody(index: index),
                    createdAt: baseDate.addingTimeInterval(offset + 2),
                    turnID: turnID
                ),
                to: conversationID
            )
        }
    }

    /// 超大会话：600 轮（1200 条消息），用于压「大数据量」路径。
    ///
    /// 正文刻意比 `largeAssistantBody` 轻（不含代码块）：这个会话的目的是
    /// 让**消息条数**压过窗口上限（`maxRetainedCount` = 300），而不是让
    /// 单行高度压几何收敛。代码块会让每条消息都撑高多行，1200 条下来
    /// 文档高度过大，反而把测试变成「几何压力测试」，掩盖了数据量这条主线。
    private static func seedHuge(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        conversationID: UUID
    ) {
        for index in 0..<hugeTurnCount {
            let turnID = UUID()
            let offset = Double(index) * 10
            messages.insertMessage(
                message(
                    conversationID: conversationID,
                    role: .user,
                    content: "超大会话问题 \(index + 1)",
                    createdAt: baseDate.addingTimeInterval(offset),
                    turnID: turnID
                ),
                to: conversationID
            )
            messages.insertMessage(
                message(
                    conversationID: conversationID,
                    role: .assistant,
                    content: "超大会话回答 \(index + 1)",
                    createdAt: baseDate.addingTimeInterval(offset + 2),
                    turnID: turnID
                ),
                to: conversationID
            )
        }
    }

    /// 工具调用组会话：一条含**多个工具调用**的助手消息。
    ///
    /// 该消息正文为空 → 命中 `isToolExecutionOnly` → 数据层合成
    /// `turn-activity` 消息 → 渲染层折叠成一行摘要。
    ///
    /// 另外插入一条**单个工具调用**的助手消息作为对照：
    /// 单个调用不应被折叠，仍逐条铺开显示。
    private static func seedToolGroup(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        conversationID: UUID
    ) {
        let turnID = UUID()
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: "工具调用组问题",
                createdAt: baseDate,
                turnID: turnID
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "",
                createdAt: baseDate.addingTimeInterval(1),
                turnID: turnID,
                toolCalls: [
                    toolCall(id: "group-1", name: "read_file", description: "读取文件"),
                    toolCall(id: "group-2", name: "search", description: "搜索代码"),
                    toolCall(id: "group-3", name: "run_command", description: "运行测试"),
                ]
            ),
            to: conversationID
        )

        // 对照组：单个工具调用，不折叠。
        let singleTurnID = UUID()
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: "单个工具调用问题",
                createdAt: baseDate.addingTimeInterval(10),
                turnID: singleTurnID
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "",
                createdAt: baseDate.addingTimeInterval(11),
                turnID: singleTurnID,
                toolCalls: [
                    toolCall(id: "single-1", name: "read_file", description: "读取单个文件")
                ]
            ),
            to: conversationID
        )

        conversations.setVerbosity(.standard, for: conversationID)
    }

    /// 构造一条已完成的工具调用。
    private static func toolCall(
        id: String,
        name: String,
        description: String
    ) -> MessageToolCall {
        MessageToolCall(
            id: id,
            name: name,
            arguments: "{}",
            result: MessageToolResult(
                content: "ok",
                duration: 1,
                isError: false
            ),
            displayDescription: description,
            authorizationState: "autoApproved"
        )
    }

    /// 每轮交替使用 Markdown 标题、列表与代码块，制造多行富文本行高。
    private static func largeAssistantBody(index: Int) -> String {
        """
        ## 第 \(index + 1) 轮小结

        - 条目 A：说明一
        - 条目 B：说明二
        - 条目 C：说明三

        ```swift
        func round\(index + 1)() -> Int {
            return \(index + 1)
        }
        ```

        结论：第 \(index + 1) 轮已完成。
        """
    }

    private static func message(
        conversationID: UUID,
        role: MessageRole,
        content: String,
        createdAt: Date,
        turnID: UUID?
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: role,
            content: content,
            createdAt: createdAt,
            turnID: turnID
        )
    }
}

/// 不需要清理的句柄占位。
@MainActor
private final class NoopObserverHandle: ConversationObserverHandle {
    func cancel() {}
}

/// 让一次性观察者闭包能引用到自己的注销句柄（自取消语义）。
@MainActor
private final class OneShotObserverBox {
    var handle: (any ConversationObserverHandle)?
}
#endif
