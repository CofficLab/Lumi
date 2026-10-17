#if DEBUG
import Foundation
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

    private static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// 大会话的 turn 数。足够让 List 懒加载多帧，逼近收敛上限。
    private static let largeTurnCount = 40

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    @discardableResult
    static func seed(
        conversations: any ConversationManaging,
        messages: any MessageManaging
    ) -> any ConversationObserverHandle {
        guard !hasSeeded(conversations: conversations) else {
            return NoopObserverHandle()
        }
        if !conversations.isLoadingConversations {
            doSeed(conversations: conversations, messages: messages)
            return NoopObserverHandle()
        }
        let box = OneShotObserverBox()
        let handle = conversations.addConversationObserver { event in
            guard event == .listChanged else { return }
            // 一次性：先注销自己，再 seed（seed 会再次触发 listChanged）。
            box.handle?.cancel()
            box.handle = nil
            doSeed(conversations: conversations, messages: messages)
        }
        box.handle = handle
        return handle
    }

    private static func hasSeeded(conversations: any ConversationManaging) -> Bool {
        conversations.conversations.contains { $0.title == smallConversationTitle }
    }

    private static func doSeed(
        conversations: any ConversationManaging,
        messages: any MessageManaging
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

        seedSmall(conversations: conversations, messages: messages, conversationID: small)
        seedLarge(conversations: conversations, messages: messages, conversationID: large)

        // 选中大会话：它是更难收敛的一侧，作为 UI 测试的起始态。
        conversations.selectConversation(id: large)
        conversations.setVerbosity(.standard, for: large)
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
