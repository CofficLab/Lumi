#if canImport(XCTest)
import XCTest
@testable import Lumi

/// 聊天消息（ChatMessage）单元测试
///
/// 验证 `ChatMessage` 模型的各种计算属性，这些属性集中了消息在 UI 展示、
/// LLM 上下文构建、工具调用判断等方面的业务规则。
///
/// 测试覆盖以下属性：
/// - `shouldSendToLLM`：哪些角色应作为对话上下文发送给大模型
/// - `shouldShowToolbar`：哪些角色应在消息气泡下方显示操作栏
/// - `isToolOutput`：消息是否为工具执行结果
/// - `hasToolCalls`：消息是否包含 AI 发起的工具调用
/// - `hasSendableContent`：消息是否包含可发送的文本或图片
/// - `shouldDisplayInChatList`：消息是否应展示在聊天列表中
final class ChatMessageTests: XCTestCase {

    /// 便捷工厂方法，用于快速构造测试用 ChatMessage。
    ///
    /// 所有参数均设有默认值，测试中只需指定关心的字段即可。
    /// `conversationId` 自动生成 UUID，不影响测试断言。
    private func makeMessage(
        role: MessageRole = .user,
        content: String = "hello",
        toolCallID: String? = nil,
        toolCalls: [ToolCall]? = nil,
        images: [ImageAttachment] = [],
        isError: Bool = false
    ) -> ChatMessage {
        ChatMessage(
            role: role,
            conversationId: UUID(),
            content: content,
            isError: isError,
            toolCalls: toolCalls,
            toolCallID: toolCallID,
            images: images
        )
    }

    // MARK: - shouldSendToLLM
    // 以下测试验证 shouldSendToLLM 属性在不同角色下的返回值。
    // 规则：仅 user、assistant、tool 三种角色应发送给 LLM，
    // 其余角色（system、status、error、unknown）属于本地辅助消息，不参与 LLM 对话。

    /// user 消息是用户输入，必须发送给 LLM。
    func testShouldSendToLLM_returnsTrueForUser() {
        XCTAssertTrue(makeMessage(role: .user).shouldSendToLLM)
    }

    /// assistant 消息是 AI 的回复，作为历史上下文发送给 LLM。
    func testShouldSendToLLM_returnsTrueForAssistant() {
        XCTAssertTrue(makeMessage(role: .assistant).shouldSendToLLM)
    }

    /// tool 消息是工具执行结果，需要返回给 LLM 以便继续推理。
    func testShouldSendToLLM_returnsTrueForTool() {
        XCTAssertTrue(makeMessage(role: .tool).shouldSendToLLM)
    }

    /// system 消息是系统级提示词，由 Provider 单独注入，不混入消息列表。
    func testShouldSendToLLM_returnsFalseForSystem() {
        XCTAssertFalse(makeMessage(role: .system).shouldSendToLLM)
    }

    /// status 消息是 UI 临时状态（如"连接中"），不应持久化或发送给 LLM。
    func testShouldSendToLLM_returnsFalseForStatus() {
        XCTAssertFalse(makeMessage(role: .status).shouldSendToLLM)
    }

    /// error 消息是本地错误提示，不应泄露给 LLM。
    func testShouldSendToLLM_returnsFalseForError() {
        XCTAssertFalse(makeMessage(role: .error).shouldSendToLLM)
    }

    /// unknown 消息表示数据异常，不应发送给 LLM。
    func testShouldSendToLLM_returnsFalseForUnknown() {
        XCTAssertFalse(makeMessage(role: .unknown).shouldSendToLLM)
    }

    // MARK: - shouldShowToolbar
    // 以下测试验证消息气泡下方工具栏（复制/操作按钮行）的展示规则。
    // 规则：user、assistant、error 消息展示工具栏，其余角色不展示。

    /// user 和 assistant 消息是用户和 AI 的主要对话内容，需要展示复制等操作。
    func testShouldShowToolbar_returnsTrueForUserAndAssistant() {
        XCTAssertTrue(makeMessage(role: .user).shouldShowToolbar)
        XCTAssertTrue(makeMessage(role: .assistant).shouldShowToolbar)
    }

    /// error 消息也需要工具栏，方便用户复制错误详情进行排查。
    func testShouldShowToolbar_returnsTrueForError() {
        XCTAssertTrue(makeMessage(role: .error).shouldShowToolbar)
    }

    /// system 消息是内部提示词，用户无需看到，自然也不需要工具栏。
    func testShouldShowToolbar_returnsFalseForSystem() {
        XCTAssertFalse(makeMessage(role: .system).shouldShowToolbar)
    }

    // MARK: - isToolOutput
    // 以下测试验证消息是否为工具执行结果的判断逻辑。
    // 判断依据：toolCallID 是否非 nil。

    /// 当 toolCallID 有值时，说明该消息是某个工具调用的执行结果。
    func testIsToolOutput_returnsTrueWhenToolCallIDIsSet() {
        let msg = makeMessage(role: .tool, toolCallID: "call_123")
        XCTAssertTrue(msg.isToolOutput)
    }

    /// 普通用户消息没有 toolCallID，不是工具输出。
    func testIsToolOutput_returnsFalseWhenToolCallIDIsNil() {
        let msg = makeMessage(role: .user)
        XCTAssertFalse(msg.isToolOutput)
    }

    // MARK: - hasToolCalls
    // 以下测试验证消息是否包含 AI 发起的工具调用列表。
    // 判断依据：toolCalls 数组非空。

    /// 当 toolCalls 包含至少一个 ToolCall 时，说明 AI 请求执行工具。
    func testHasToolCalls_returnsTrueWhenToolCallsPresent() {
        let toolCall = ToolCall(id: "call_1", name: "read_file", arguments: "{}")
        let msg = makeMessage(role: .assistant, toolCalls: [toolCall])
        XCTAssertTrue(msg.hasToolCalls)
    }

    /// toolCalls 为 nil 时（默认值），没有工具调用。
    func testHasToolCalls_returnsFalseWhenNil() {
        let msg = makeMessage(role: .assistant)
        XCTAssertFalse(msg.hasToolCalls)
    }

    /// toolCalls 为空数组时，也没有工具调用。
    func testHasToolCalls_returnsFalseWhenEmpty() {
        let msg = makeMessage(role: .assistant, toolCalls: [])
        XCTAssertFalse(msg.hasToolCalls)
    }

    // MARK: - hasSendableContent
    // 以下测试验证消息是否包含可发送的内容（文本或图片）。
    // 判断依据：去除空白后文本非空，或包含图片附件。

    /// 包含有效文本的消息可以直接发送。
    func testHasSendableContent_returnsTrueForNonEmptyText() {
        let msg = makeMessage(content: "hello")
        XCTAssertTrue(msg.hasSendableContent)
    }

    /// 仅包含空白字符的消息视为无内容，不应发送。
    func testHasSendableContent_returnsFalseForWhitespaceOnly() {
        let msg = makeMessage(content: "   \n\t  ")
        XCTAssertFalse(msg.hasSendableContent)
    }

    /// 空字符串也没有可发送内容。
    func testHasSendableContent_returnsFalseForEmptyString() {
        let msg = makeMessage(content: "")
        XCTAssertFalse(msg.hasSendableContent)
    }

    // MARK: - shouldDisplayInChatList
    // 以下测试验证消息是否应展示在聊天消息列表中。
    // 规则：user、assistant、status、error 展示；tool、system、unknown 隐藏。

    /// user 和 assistant 是主要对话内容，始终在聊天列表中展示。
    func testShouldDisplayInChatList_userAndAssistant() {
        XCTAssertTrue(makeMessage(role: .user).shouldDisplayInChatList())
        XCTAssertTrue(makeMessage(role: .assistant).shouldDisplayInChatList())
    }

    /// tool 消息是工具执行的原始输出，信息冗长，在聊天列表中隐藏。
    func testShouldDisplayInChatList_toolReturnsFalse() {
        XCTAssertFalse(makeMessage(role: .tool).shouldDisplayInChatList())
    }

    /// system 消息是内部提示词，不应暴露给用户。
    func testShouldDisplayInChatList_systemReturnsFalse() {
        XCTAssertFalse(makeMessage(role: .system).shouldDisplayInChatList())
    }
}
#endif
