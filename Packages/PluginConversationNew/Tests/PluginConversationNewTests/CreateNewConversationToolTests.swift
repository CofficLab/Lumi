import Foundation
import KitAgentTool
import Testing
@testable import PluginConversationNew

@Suite("CreateNewConversationTool")
@MainActor
struct CreateNewConversationToolTests {

    // MARK: - 参数解析

    @Test("task 缺失或空白时抛出执行失败")
    func missingTaskThrows() async {
        let capability = MockNewChatCapability()
        let tool = CreateNewConversationTool(conversations: capability)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: ["task": ToolArgument("   \n ")])
        }
        #expect(capability.createdConversations.isEmpty, "参数非法时不应创建任何对话")
    }

    @Test("title 缺省或空白时由 task 推导")
    func titleFallsBackToDerived() async {
        let capability = MockNewChatCapability()
        let tool = CreateNewConversationTool(conversations: capability)

        _ = try? await tool.execute(arguments: ["task": ToolArgument("Investigate the flaky login test. Then ship it.")])
        #expect(capability.createdConversations.count == 1)
        #expect(capability.createdConversations.first?.title == "Investigate the flaky login test")

        _ = try? await tool.execute(arguments: [
            "task": ToolArgument("Second task"),
            "title": ToolArgument("   "),
        ])
        #expect(capability.createdConversations.last?.title == "Second task")
    }

    @Test("显式 title 优先于推导标题")
    func explicitTitleWins() async {
        let capability = MockNewChatCapability()
        let tool = CreateNewConversationTool(conversations: capability)

        _ = try? await tool.execute(arguments: [
            "task": ToolArgument("Investigate the flaky login test. Then ship it."),
            "title": ToolArgument("CI failure"),
        ])
        #expect(capability.createdConversations.first?.title == "CI failure")
    }

    // MARK: - 关键不变量：回合内不切换选中态

    @Test("创建对话后选中态被恢复为原对话")
    func selectionIsRestoredAfterCreate() async throws {
        let original = UUID()
        let capability = MockNewChatCapability()
        capability.restoreSelection(to: original)

        let tool = CreateNewConversationTool(conversations: capability)
        let output = try await tool.execute(arguments: ["task": ToolArgument("Do an unrelated task here")])

        #expect(capability.selectedConversationID == original, "回合内不得留下新建对话的选中态")
        #expect(capability.restoredSelections.last == original)
        #expect(capability.selections.isEmpty, "工具不应主动切换对话")
        #expect(output.contains("New Conversation Prepared"))
    }

    @Test("创建失败时同样恢复选中态")
    func selectionIsRestoredOnFailure() async throws {
        struct Boom: Error {}
        let original = UUID()
        let capability = MockNewChatCapability()
        capability.restoreSelection(to: original)
        capability.createError = Boom()

        let tool = CreateNewConversationTool(conversations: capability)
        let output = try await tool.execute(arguments: ["task": ToolArgument("Do an unrelated task here")])

        #expect(capability.selectedConversationID == original, "失败路径不得把用户留在空对话里")
        #expect(capability.restoredSelections.last == original)
        #expect(output.contains("New Conversation Not Prepared"))
    }

    @Test("无能力时返回失败文本且不抛出")
    func missingCapabilityReturnsFailureText() async throws {
        let tool = CreateNewConversationTool(conversations: nil)
        let output = try await tool.execute(arguments: ["task": ToolArgument("Do something")])
        #expect(output.contains("New Conversation Not Prepared"))
    }

    // MARK: - 返回结构

    @Test("返回内容包含可被渲染器解析的 payload")
    func resultContainsDecodablePayload() async throws {
        let capability = MockNewChatCapability()
        let tool = CreateNewConversationTool(conversations: capability)

        let task = "Investigate the flaky login test on CI."
        let output = try await tool.execute(arguments: ["task": ToolArgument(task)])

        let suggestion = try #require(NewConversationRowRenderer.decodeSuggestion(from: output))
        #expect(suggestion.starter == task)
        #expect(suggestion.title == "Investigate the flaky login test on CI")
        #expect(capability.createdConversations.first?.title == suggestion.title)
    }

    @Test("创建对话时透传当前项目与模型")
    func createInheritsProjectAndModel() async throws {
        let capability = MockNewChatCapability()
        capability.modelID = "anthropic/claude-sonnet"
        capability.projectPath = "/tmp/demo"
        let tool = CreateNewConversationTool(conversations: capability)

        _ = try await tool.execute(arguments: ["task": ToolArgument("Another task")])

        let created = try #require(capability.createdConversations.first)
        #expect(created.modelID == "anthropic/claude-sonnet")
        #expect(created.projectPath == "/tmp/demo")
    }

    // MARK: - 标题推导

    @Test(
        "标题推导取首句并截断",
        arguments: [
            ("Short one. Second sentence.", "Short one"),
            ("No terminator at all", "No terminator at all"),
            ("Line one\nLine two", "Line one"),
        ]
    )
    func derivedTitleUsesFirstSentence(input: String, expected: String) {
        #expect(CreateNewConversationTool.derivedTitle(from: input) == expected)
    }

    @Test("超长标题被截断到上限")
    func derivedTitleTruncates() {
        let long = String(repeating: "a", count: 200)
        let title = CreateNewConversationTool.derivedTitle(from: long)
        #expect(title.count == CreateNewConversationTool.maxDerivedTitleLength)
    }

    // MARK: - 风险与展示

    @Test("风险等级为 low，inputSchema 要求 task")
    func schemaAndRisk() {
        let tool = CreateNewConversationTool(conversations: nil)
        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)

        let schema = tool.inputSchema(for: .english)
        let properties = schema["properties"] as? [String: Any]
        #expect(properties?["task"] != nil)
        #expect(properties?["title"] != nil)
        #expect(schema["required"] as? [String] == ["task"])
    }

    @Test("展示描述包含标题")
    func displayDescriptionIncludesTitle() {
        let tool = CreateNewConversationTool(conversations: nil)
        let text = tool.displayDescription(for: [
            "task": ToolArgument("Do something unrelated"),
            "title": ToolArgument("Standalone topic"),
        ])
        #expect(text.contains("Standalone topic"))
    }
}
