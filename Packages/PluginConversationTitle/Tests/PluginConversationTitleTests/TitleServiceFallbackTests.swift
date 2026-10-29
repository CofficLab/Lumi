import Foundation
import KernelCore
import ProviderConversation
import ProviderMessage
import Testing

@testable import PluginConversationTitle

/// 复现：**自动标题失败后，对话永远没有标题。**
///
/// ## 现象
///
/// `TitleService` 在首条用户消息插入时调用 LLM 生成标题。这个调用一旦失败
/// （401 鉴权失败、额度耗尽、网络中断……），当前实现只打一条 error 日志就
/// 结束——**没有兜底标题、没有重试、没有补写**。
///
/// 结果是这条对话的 `ZTITLE` 永久停在 `''`，在列表里只能显示通用占位符
/// 「对话」，看起来就是「一条空白的条目」——哪怕它有几百条消息。
///
/// 生产环境已确认这不是假设：正式版日志里有 3 次
/// `Failed to generate conversation title ... HTTP 401`，对应的 3 条对话
/// 全部落在「空标题」名单里（167 / 43 / 558 条消息），且最后消息时间与
/// 日志文件时间一一对应。
///
/// ## 不变量
///
/// **对话列表里不允许出现没有可读标题的条目。**
///
/// LLM 失败不代表用户没有说过话——首条用户消息本身就是最好的标题素材。
/// 因此失败路径必须写入**占位标题**（首条用户消息的截断文本），而不是让
/// 对话停留在「无标题」状态。
///
/// 占位标题是可被覆盖的：后续 LLM 成功时，现有 `shouldApplyGeneratedTitle`
/// 已经允许用生成标题替换占位标题（它正是为此而写的）。
///
/// - Note: 这些用例**现在应当失败**。它们是缺陷的复现，不是对现状的认可。
@Suite("自动标题失败的兜底")
@MainActor
struct TitleServiceFallbackTests {

    private func makeService(
        messages: TitleTestDoubles.StubMessageManager,
        conversations: TitleTestDoubles.StubConversationManager,
        llm: TitleTestDoubles.StubLLMManager
    ) -> TitleService {
        TitleService(
            kernel: KernelCoreContainer(),
            conversations: conversations,
            messages: messages,
            llmProvider: llm
        )
    }

    private func userMessage(_ content: String, in conversationID: UUID) -> Message {
        Message(conversationID: conversationID, role: .user, content: content)
    }

    /// 事件回调内部是 `Task { @MainActor }`，需要让出执行权等它跑完。
    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }

    /// LLM 调用抛错时，对话仍然必须拿到一个可读标题。
    ///
    /// 修复前：只记日志，标题保持 `nil` → 列表里是一条「空的」条目。
    @Test("标题生成抛错时写入占位标题")
    func fallsBackWhenLLMThrows() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(
            completionError: StubLLMError(reason: "HTTP 401")
        )

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("帮我把这段 Swift 代码重构一下", in: conversationID))
        await settle()

        let title = conversations.title(of: conversationID)
        #expect(
            !(title ?? "").isEmpty,
            "标题生成失败后对话仍然没有任何标题，列表里会显示成空白条目"
        )
        #expect(
            title == TitleService.placeholderTitle(forFirstUserMessage: "帮我把这段 Swift 代码重构一下"),
            "占位标题应取自首条用户消息，实际「\(title ?? "nil")」"
        )
    }

    /// LLM 返回空字符串（没有抛错）时，同样要兜底。
    ///
    /// 这条路径同样会让对话永远停在无标题状态，且比抛错更隐蔽——没有异常，
    /// 只有一条 error 日志。
    @Test("标题生成为空时写入占位标题")
    func fallsBackWhenLLMReturnsEmptyTitle() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        // 只有空白与引号，清洗后为空串
        let llm = TitleTestDoubles.StubLLMManager(responseContent: "   “”  \n  ")

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("统计一下这个仓库的测试覆盖率", in: conversationID))
        await settle()

        let title = conversations.title(of: conversationID)
        #expect(
            !(title ?? "").isEmpty,
            "LLM 返回空标题后对话仍然没有任何标题，列表里会显示成空白条目"
        )
    }

    /// 兜底**不得**覆盖用户手动改过的标题。
    ///
    /// 占位标题是「系统没取到更好的标题时的替补」，不是「应该覆盖用户输入」。
    /// 用户自己写的标题优先级最高，任何失败路径都不能动它。
    @Test("兜底不覆盖用户自定义标题")
    func fallbackDoesNotOverwriteCustomTitle() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: "我手动写的标题")
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(
            completionError: StubLLMError(reason: "HTTP 401")
        )

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage("首个问题", in: conversationID))
        await settle()

        #expect(conversations.title(of: conversationID) == "我手动写的标题")
    }

    /// 占位标题必须来自用户自己的话，不能是 LLM 生成的空壳。
    ///
    /// 占位标题取首条用户消息的空白折叠 + 截断（≤40 字）。
    @Test("占位标题取自首条用户消息并截断")
    func placeholderTitleComesFromFirstUserMessage() async {
        let long = String(repeating: "很长的需求描述 ", count: 10)
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(
            completionError: StubLLMError(reason: "HTTP 401")
        )

        let service = makeService(
            messages: messages,
            conversations: conversations,
            llm: llm
        )
        defer { service.stop() }

        messages.emitInserted(userMessage(long, in: conversationID))
        await settle()

        let title = conversations.title(of: conversationID) ?? ""
        #expect(!title.isEmpty)
        #expect(title.count <= 41, "占位标题过长：\(title.count) 字")
        #expect(long.hasPrefix(title.dropLast()), "占位标题应是首条用户消息的前缀")
    }
}
