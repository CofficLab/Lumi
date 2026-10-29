#if DEBUG
import Foundation
import ProviderConversation
import ProviderMessage

/// PluginMessageListDetailed（V3 / 详细模式）的 UI 测试夹具（仅 DEBUG）。
///
/// ## 为什么要单独一份夹具
///
/// 已有夹具 `--lumi-ui-testing-message-list-standard` 把会话的详细程度固定为
/// `.standard`，激活的是 **V2** 列表槽位。用户实际遇到的卡死发生在**详细模式**
/// （V3）——两者的视图结构不同（V3 多一行 `streamingRow` / `activityRow`），
/// 遮罩编排却来自各自插件内的一份拷贝，因此 V3 必须有**自己的**端到端夹具：
/// 否则「V2 通过」并不能说明 V3 的遮罩不会卡死。
///
/// ## 植入什么
///
/// - `Detailed Target Small`：3 轮，几何很快收敛；
/// - `Detailed Target Large`：40 轮 + Markdown/代码块，几何持续增长，
///   最容易逼近收敛上限、也最容易把遮罩挂住。
///
/// ## 启动参数
/// - `--lumi-ui-testing-message-list-detailed`：启用本夹具。
/// - `--lumi-ui-testing-isolated-storage`：建议同时启用，避免污染用户数据。
@MainActor
public enum MessageListDetailedUITestingSupport {
    public static let launchArgument = "--lumi-ui-testing-message-list-detailed"

    /// 小会话标题（易收敛）。
    public static let smallConversationTitle = "Detailed Target Small"
    /// 大会话标题（几何持续增长，最易挂住遮罩）。
    public static let largeConversationTitle = "Detailed Target Large"

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

        // 详细程度必须是 `.detailed`：V3 列表槽位只在详细程度为 detailed 时激活，
        // 否则 UI 测试测的是 V2 而不是 V3。
        conversations.setVerbosity(.detailed, for: small)
        conversations.setVerbosity(.detailed, for: large)

        // 选中大会话：它是更难收敛的一侧，作为 UI 测试的起始态。
        conversations.selectConversation(id: large)
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
                    content: "详细小会话问题 \(index + 1)",
                    createdAt: baseDate.addingTimeInterval(Double(index) * 10),
                    turnID: turnID
                ),
                to: conversationID
            )
            messages.insertMessage(
                message(
                    conversationID: conversationID,
                    role: .assistant,
                    content: "详细小会话回答 \(index + 1)",
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
                    content: "详细大会话问题 \(index + 1)",
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
