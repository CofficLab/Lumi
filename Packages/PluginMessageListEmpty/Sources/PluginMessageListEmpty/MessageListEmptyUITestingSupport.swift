#if DEBUG
import Foundation
import ProviderConversation
import ProviderMessage
import ProviderProject

/// PluginMessageListEmpty 的 UI 测试夹具（仅 DEBUG）。
///
/// 植入三个子会话，分别对应空态的三条互斥判定分支。
///
/// ## 为什么需要「历史会话」这一个
///
/// 底部活动条的数据来自**跨会话**的 30 天统计
/// （`dailyMessageCountsAsync`），与当前选中的空会话无关。因此要让
/// 「空态 + 活动条」同时出现，必须在**另一个**会话里留下历史消息：
/// 只植入一个空会话的话，活动条会因为 `hasActivity == false` 而整体不渲染，
/// 用例断言不到本插件最想守住的那条路径。
///
/// 三个会话的职责：
/// - `emptyConversationTitle`：空会话 → 空态 + 活动条同时可见（主用例）。
/// - `historyConversationTitle`：带消息的历史会话 → 供活动条统计，
///   同时作为「有消息时不显示空态」的对照组。
/// - `toolOnlyConversationTitle`：只有 tool 消息的会话 → 验证
///   `includesToolMessages: false` 判定下它仍算「空」，工具输出不该把用户
///   从空态里拽出来（单测已覆盖该判定，UI 层再验一次端到端表现）。
///
/// ## 启动参数
/// - `--lumi-ui-testing-message-list-empty`：启用本夹具。
/// - `--lumi-ui-testing-isolated-storage`：建议同时启用，避免污染用户数据。
///
/// 范式参照 `MessageListStandardUITestingSupport`：必须等
/// `loadConversations()` 完成后再 seed，否则会被整表加载覆盖。
@MainActor
public enum MessageListEmptyUITestingSupport {
    public static let launchArgument = "--lumi-ui-testing-message-list-empty"

    /// 额外启动参数：植入一个项目，并让会话归属该项目。
    ///
    /// 项目上下文卡（身份行 + 就绪状态）只在**有项目**时渲染，因此验证它
    /// 必须真的打开一个项目。这个参数让夹具建一个临时项目目录（含
    /// `Package.swift` 与 `README.md`），并把会话挂到这个项目下——
    /// 这样项目维度的活动统计也有数据可数。
    public static let projectLaunchArgument = "--lumi-ui-testing-message-list-empty-project"

    /// 空会话：无任何消息，用于验证空态与活动条同时出现。
    public static let emptyConversationTitle = "UI Empty State Target"
    /// 历史会话：有 user 消息，供活动条统计，同时作为有消息的对照组。
    public static let historyConversationTitle = "UI Empty State History"
    /// 仅 tool 消息的会话：按 `includesToolMessages: false` 判定仍算空。
    public static let toolOnlyConversationTitle = "UI Empty State ToolOnly"

    /// 活动条无障碍摘要里出现的量词前缀，UI 测试据此确认摘要真的存在。
    ///
    /// 摘要已不再画在界面上（活动条只显示热力图与折线图），只作为容器的
    /// accessibility label，与 `ActivityFooterView.summaryText` 的格式串
    /// 「"%lld messages in the last %lld days"」对应。
    public static let activitySummaryPrefix = "messages in the last"

    /// 历史消息的天数跨度。覆盖窗口首、中、尾三处，验证 30 天窗口被完整填充。
    private static let historyOffsetsInDays = [0, 3, 12, 29]

    private static func historyDate(daysAgo: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    }

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// 夹具总开关。单元测试可复用同一份夹具而不必构造真实启动参数。
    static func isEnabled(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    @discardableResult
    static func seed(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        project: (any ProjectProviding)? = nil
    ) -> any ConversationObserverHandle {
        guard !hasSeeded(conversations: conversations) else {
            return NoopObserverHandle()
        }
        if !conversations.isLoadingConversations {
            doSeed(conversations: conversations, messages: messages, project: project)
            return NoopObserverHandle()
        }
        let box = OneShotObserverBox()
        let handle = conversations.addConversationObserver { event in
            guard event == .listChanged else { return }
            // 一次性：先注销自己，再 seed（seed 会再次触发 listChanged）。
            box.handle?.cancel()
            box.handle = nil
            doSeed(conversations: conversations, messages: messages, project: project)
        }
        box.handle = handle
        return handle
    }

    private static func hasSeeded(conversations: any ConversationManaging) -> Bool {
        conversations.conversations.contains { $0.title == emptyConversationTitle }
    }

    private static func doSeed(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        project: (any ProjectProviding)?
    ) {
        // 需要项目时建一个临时目录（含清单文件），让项目类型判定与关键文件标签有内容。
        guard let root = makeFixtureProjectDirectoryIfRequested() else {
            createConversations(conversations: conversations, messages: messages, projectPath: nil)
            return
        }

        // - Important: 必须**先**切项目、再种会话。
        //
        //   `ConversationManager` 监听项目切换，切换原因是 `.userSelected` 时会
        //   **清空会话选择**。若先种会话并选中、再切项目，刚选中的空会话会被
        //   这次切换抹掉，UI 测试看到的就成了「未选中任何会话」的空态。
        //
        //   真实用户的顺序也正是这样：先打开项目，再开始对话。
        Task { @MainActor in
            try? await project?.openProject(at: root, reason: .userSelected)
            createConversations(conversations: conversations, messages: messages, projectPath: root)
        }
    }

    /// 建会话、灌消息、选中空会话。
    private static func createConversations(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        projectPath: String?
    ) {
        guard let empty = try? conversations.createConversation(
            title: emptyConversationTitle,
            projectPath: projectPath,
            providerID: nil,
            modelName: nil
        ) else { return }

        guard let history = try? conversations.createConversation(
            title: historyConversationTitle,
            projectPath: projectPath,
            providerID: nil,
            modelName: nil
        ) else { return }

        guard let toolOnly = try? conversations.createConversation(
            title: toolOnlyConversationTitle,
            projectPath: projectPath,
            providerID: nil,
            modelName: nil
        ) else { return }

        seedHistory(conversations: conversations, messages: messages, conversationID: history)
        seedToolOnly(conversations: conversations, messages: messages, conversationID: toolOnly)

        // 选中空会话：UI 测试的起始态，也是「空态 + 活动条」的唯一入口。
        conversations.selectConversation(id: empty)
    }

    /// 需要项目时建一个临时项目目录，返回它的路径；否则返回 nil。
    private static func makeFixtureProjectDirectoryIfRequested() -> String? {
        guard ProcessInfo.processInfo.arguments.contains(projectLaunchArgument) else { return nil }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-ui-empty-state-project-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // 两个入口文件：项目类型判定与「关键文件」标签都靠它们。
        try? Data().write(to: root.appendingPathComponent("Package.swift"))
        try? Data().write(to: root.appendingPathComponent("README.md"))
        return root.path
    }

    /// 历史会话：跨 30 天窗口铺开 user 消息，供活动条统计出非零值。
    ///
    /// 只用 `.user` 角色是有意的：活动条走 `dailyMessageCountsAsync`，
    /// 与空态判定用的 `messagePageAsync(includesToolMessages: false)` 是
    /// 两条独立路径，历史会话若混入 tool 消息就无法区分是哪条路径在起作用。
    private static func seedHistory(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        conversationID: UUID
    ) {
        for (index, daysAgo) in historyOffsetsInDays.enumerated() {
            let date = historyDate(daysAgo: daysAgo)
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: "UI history message \(index + 1)",
                    createdAt: date
                ),
                to: conversationID
            )
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .assistant,
                    content: "UI history reply \(index + 1)",
                    createdAt: date.addingTimeInterval(1),
                    inputTokenCount: 1_200,
                    outputTokenCount: 800
                ),
                to: conversationID
            )
        }
    }

    /// 仅 tool 消息：判定时 `includesToolMessages: false`，因此仍应显示空态。
    private static func seedToolOnly(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        conversationID: UUID
    ) {
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .tool,
                content: "UI tool output",
                createdAt: historyDate(daysAgo: 1)
            ),
            to: conversationID
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
