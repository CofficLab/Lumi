#if DEBUG
import Foundation
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// V4（ZCode）消息列表的 UI 测试夹具。
///
/// ## 为什么要单独一份夹具
///
/// V1–V3 各自有独立的列表槽位与遮罩编排（`InitialPositionGate` 在每个插件内各有一份），
/// 因此「V2 通过」并不能说明 V4 的遮罩不会卡死。V4 必须有**自己的**端到端夹具。
///
/// ## 植入什么
///
/// 5 个固定会话，覆盖 ZCode 时间线的各类形态：
///
/// | 会话 | 用途 |
/// |---|---|
/// | `ZCode Visual Target` | 常规轮次：用户气泡 + 助手正文 + 轮尾操作栏 |
/// | `ZCode Long User Target` | 超长用户输入，触发长文折叠 |
/// | `ZCode Tool Target` | 多个 Explore/Execute 工具调用，触发工作历史分组 |
/// | `ZCode Scroll Target` | 30 轮长列表，用于滚动与 following 语义 |
/// | `ZCode Streaming Target` | 标记为流式，用于流式态验收 |
///
/// ## 启动参数
///
/// - `--lumi-ui-testing`：**必需**。全局 UI 测试开关。
/// - `--lumi-ui-testing-message-list-zcode`：启用本夹具。
/// - `--lumi-ui-testing-isolated-storage`：建议同时启用，避免污染用户数据。
///
/// ## 确定性
///
/// 所有内容、时间戳与顺序都是**固定**的：同一个启动参数集合永远产生
/// **完全相同**的会话内容，UI 测试的截图才能逐像素比对。
///
/// - Important: 整个文件置于 `#if DEBUG` 内（项目条件编译规范）。
///   引用它的插件代码必须把**整个函数体**同等包裹在 `#if DEBUG` 内，
///   否则 Release 构建会报「找不到类型」。
@MainActor
public enum MessageListZCodeUITestingSupport {

    // MARK: - 启动参数

    /// V4 夹具的专用启动参数。
    public static let launchArgument = "--lumi-ui-testing-message-list-zcode"

    /// 全局 UI 测试启动参数。
    public static let globalLaunchArgument = "--lumi-ui-testing"

    /// UI 测试是否应注入夹具。
    ///
    /// - Important: 必须**同时**带 `--lumi-ui-testing` 与 V4 专用参数。
    ///   缺少全局开关时**拒绝启用** —— 防止有人只加了 V4 参数就让
    ///   正式构建在真实环境里造出会话、连真实供应商。
    public static var isEnabled: Bool {
        isEnabled(arguments: ProcessInfo.processInfo.arguments)
    }

    /// 按给定的启动参数判定是否启用。
    ///
    /// - Note: 参数化是为了可单测；生产路径走 `isEnabled`。
    public static func isEnabled(arguments: [String]) -> Bool {
        arguments.contains(globalLaunchArgument) && arguments.contains(launchArgument)
    }

    // MARK: - 固定会话定义

    /// 常规视觉会话标题。
    public static let visualConversationTitle = "ZCode Visual Target"
    /// 长用户输入会话标题。
    public static let longUserConversationTitle = "ZCode Long User Target"
    /// 工具历史会话标题。
    public static let toolConversationTitle = "ZCode Tool Target"
    /// 滚动长列表会话标题。
    public static let scrollConversationTitle = "ZCode Scroll Target"
    /// 流式会话标题。
    public static let streamingConversationTitle = "ZCode Streaming Target"

    /// 全部固定会话标题，顺序稳定。
    public static let fixtureTitles: [String] = [
        visualConversationTitle,
        longUserConversationTitle,
        toolConversationTitle,
        scrollConversationTitle,
        streamingConversationTitle,
    ]

    /// 基准时间戳；固定值，保证时间标签可预测。
    public static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// 滚动长列表会话的轮数。
    public static let scrollTurnCount = 30

    /// 长用户输入的正文。
    public static let longUserContentLength = 2_400

    /// 长用户输入的正文长度。
    public static var longUserContent: String {
        // 固定长度、确定内容：不使用随机数，也不依赖时间。
        let seed = "ZCode 长输入夹具：用于验证用户气泡在超过折叠阈值时的截断与展开行为。"
        var result = ""
        var index = 0
        while result.count < longUserContentLength {
            result += seed
            result += " 第\(index)段。\n"
            index += 1
        }
        return String(result.prefix(longUserContentLength))
    }

    /// 常规视觉会话的用户正文。
    public static let visualUserContent = "请用三句话说明 ZCode 消息列表的轮次组织方式。"

    /// 常规视觉会话的助手正文。
    public static let visualAssistantContent = """
    ZCode 把消息按**轮次**组织，而不是按行组织。

    1. 一轮里的用户气泡、助手正文与工作历史被包进同一个外壳；
    2. 轮尾操作栏因此只出现一次，且挂在轮尾助手正文上；
    3. 助手正文没有气泡、没有头像、没有名称，占满内容列。
    """

    /// 工具会话的工具名。
    ///
    /// - Important: 至少两个同族（Explore / Execute）工具，
    ///   这样 V4 的工作历史分组才会被触发。
    public static let toolCallNames = ["Explore", "Execute"]

    /// 工具会话的用户正文。
    public static let toolUserContent = "先探索一下这个仓库的结构，再执行一次构建。"

    /// 流式会话的用户正文。
    public static let streamingUserContent = "正在生成的回答……"

    /// 流式会话是否标记为流式。
    public static var isStreamingFixture: Bool { true }

    /// 夹具日志。
    ///
    /// - Note: 只在 DEBUG 下存在；分类名固定，便于 UI 测试排查时过滤。
    private static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.message-list.zcode.uitesting"
    )

    // MARK: - 注入

    /// 注入 V4 夹具会话。
    ///
    /// - Returns: 用于取消的观察句柄；未启用时返回 nil。
    @discardableResult
    public static func seed(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: (any AgentLoopProviding)? = nil
    ) -> (any ConversationObserverHandle)? {
        guard isEnabled else {
            Self.logger.info("seed 被跳过：启动参数未齐备")
            return nil
        }
        guard !hasSeeded(conversations: conversations) else {
            return NoopZCodeObserverHandle()
        }
        // 会话列表尚未加载完成时，等 `listChanged` 再种 —— 与既有夹具同构。
        if !conversations.isLoadingConversations {
            doSeed(conversations: conversations, messages: messages, agentLoop: agentLoop)
            return NoopZCodeObserverHandle()
        }
        let box = OneShotZCodeObserverBox()
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

    /// 是否已经种过夹具。
    ///
    /// - Important: 幂等判定。重复 seed 会产生第二份同名会话，
    ///   让 UI 测试的定位锚点失效。
    private static func hasSeeded(conversations: any ConversationManaging) -> Bool {
        conversations.conversations.contains { conversation in
            guard let title = conversation.title else { return false }
            return fixtureTitles.contains(title)
        }
    }

    /// 实际种入会话。
    private static func doSeed(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: (any AgentLoopProviding)?
    ) {
        Self.logger.info("doSeed 开始")

        // 必须抑制自动回复：下面每个会话都会插入 user 消息，而
        // `PluginAgentLoop.MessageObserver` 会对 user 消息自动 `runTurn`。
        // 自动回合会写回一条 `createdAt = now` 的助手消息，把该会话的
        // `lastMessageAt` 推到「现在」——几个会话的自动回复完成时刻各不相同，
        // 于是会话列表的排序由这场竞态决定，run-to-run 不稳定。
        //
        // - Important: 抑制**只覆盖 seed 阶段**，seed 结束必须解除。
        let seededConversationIDs = [
            makeConversation(conversations: conversations, title: visualConversationTitle),
            makeConversation(conversations: conversations, title: longUserConversationTitle),
            makeConversation(conversations: conversations, title: toolConversationTitle),
            makeConversation(conversations: conversations, title: scrollConversationTitle),
            makeConversation(conversations: conversations, title: streamingConversationTitle),
        ].compactMap { $0 }

        for conversationID in seededConversationIDs {
            agentLoop?.setAutoReplySuppressed(true, for: conversationID)
        }

        let byTitle: [String: UUID] = Dictionary(
            uniqueKeysWithValues: seededConversationIDs.enumerated().map { index, id in
                (fixtureTitles[index], id)
            }
        )
        if let id = byTitle[visualConversationTitle] {
            seedVisual(messages: messages, conversationID: id)
        }
        if let id = byTitle[longUserConversationTitle] {
            seedLongUser(messages: messages, conversationID: id)
        }
        if let id = byTitle[toolConversationTitle] {
            seedTool(messages: messages, conversationID: id)
        }
        if let id = byTitle[scrollConversationTitle] {
            seedScroll(messages: messages, conversationID: id)
        }
        if let id = byTitle[streamingConversationTitle] {
            seedStreaming(messages: messages, conversationID: id)
        }

        // seed 结束：解除抑制，让 UI 测试可以在夹具会话里正常发消息。
        for conversationID in seededConversationIDs {
            agentLoop?.setAutoReplySuppressed(false, for: conversationID)
        }

        // 详细程度必须是 `.zcode`：V4 列表槽位只在详细程度为 zcode 时激活，
        // 否则 UI 测试测的是 V2 而不是 V4。
        for conversationID in seededConversationIDs {
            conversations.setVerbosity(.zcode, for: conversationID)
        }

        // 选中会话：让 UI 测试有明确的起始态。
        if let first = seededConversationIDs.first {
            conversations.selectConversation(id: first)
        }

        Self.logger.info("doSeed 完成，已种 \(seededConversationIDs.count) 个会话")
    }

    // MARK: - 各会话

    /// 常规视觉会话。
    private static func seedVisual(
        messages: any MessageManaging,
        conversationID: UUID
    ) {

        insertUser(
            messages: messages,
            conversationID: conversationID,
            content: visualUserContent,
            offset: 0
        )
        insertAssistant(
            messages: messages,
            conversationID: conversationID,
            content: visualAssistantContent,
            offset: 1
        )
    }

    /// 长用户输入会话。
    private static func seedLongUser(
        messages: any MessageManaging,
        conversationID: UUID
    ) {

        insertUser(
            messages: messages,
            conversationID: conversationID,
            content: longUserContent,
            offset: 0
        )
        insertAssistant(
            messages: messages,
            conversationID: conversationID,
            content: "已收到这段长文本。",
            offset: 1
        )
    }

    /// 工具历史会话。
    private static func seedTool(
        messages: any MessageManaging,
        conversationID: UUID
    ) {

        insertUser(
            messages: messages,
            conversationID: conversationID,
            content: toolUserContent,
            offset: 0
        )
        insertAssistantWithToolCalls(
            messages: messages,
            conversationID: conversationID,
            content: "已完成探索与执行。",
            toolNames: toolCallNames,
            offset: 1
        )
    }

    /// 滚动长列表会话。
    private static func seedScroll(
        messages: any MessageManaging,
        conversationID: UUID
    ) {

        for turn in 0..<scrollTurnCount {
            insertUser(
                messages: messages,
                conversationID: conversationID,
                content: "第 \(turn) 轮提问。",
                offset: turn * 2
            )
            insertAssistant(
                messages: messages,
                conversationID: conversationID,
                content: "第 \(turn) 轮回答。",
                offset: turn * 2 + 1
            )
        }
    }

    /// 流式会话。
    private static func seedStreaming(
        messages: any MessageManaging,
        conversationID: UUID
    ) {

        insertUser(
            messages: messages,
            conversationID: conversationID,
            content: streamingUserContent,
            offset: 0
        )
        insertAssistant(
            messages: messages,
            conversationID: conversationID,
            content: "这是正在流式生成的正文，用于验收流式态下的正文呈现、轮尾操作栏与滚动跟随。",
            offset: 1
        )
    }

    // MARK: - 写入辅助

    /// 建会话。
    private static func makeConversation(
        conversations: any ConversationManaging,
        title: String
    ) -> UUID? {
        try? conversations.createConversation(
            title: title,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
    }

    /// 插入用户消息。
    private static func insertUser(
        messages: any MessageManaging,
        conversationID: UUID,
        content: String,
        offset: Int
    ) {
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: content,
                createdAt: baseDate.addingTimeInterval(Double(offset))
            ),
            to: conversationID
        )
    }

    /// 插入助手消息。
    private static func insertAssistant(
        messages: any MessageManaging,
        conversationID: UUID,
        content: String,
        offset: Int
    ) {
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: content,
                createdAt: baseDate.addingTimeInterval(Double(offset))
            ),
            to: conversationID
        )
    }

    /// 插入带工具调用的助手消息。
    private static func insertAssistantWithToolCalls(
        messages: any MessageManaging,
        conversationID: UUID,
        content: String,
        toolNames: [String],
        offset: Int
    ) {
        let toolCalls = toolNames.enumerated().map { index, name in
            MessageToolCall(
                id: "zcode-ui-tool-\(index)",
                name: name,
                arguments: "{}"
            )
        }
        var message = Message(
            conversationID: conversationID,
            role: .assistant,
            content: content,
            createdAt: baseDate.addingTimeInterval(Double(offset))
        )
        message.toolCalls = toolCalls
        messages.insertMessage(message, to: conversationID)
    }
}

// MARK: - 观察句柄

/// 空句柄。
private final class NoopZCodeObserverHandle: ConversationObserverHandle {
    func cancel() {}
}

/// 一次性句柄盒子。
private final class OneShotZCodeObserverBox {
    var handle: (any ConversationObserverHandle)?
}
#endif
