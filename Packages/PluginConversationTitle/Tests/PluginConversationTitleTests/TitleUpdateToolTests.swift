import Foundation
import KitAgentTool
import ProviderConversation
import Testing

@testable import PluginConversationTitle

/// `TitleUpdateTool`（Agent 工具 `update_conversation_title`）的行为测试。
///
/// 覆盖三条返回 ❌ 文案的分支——它们各自对应不同的失败原因，
/// 工具返回值会直接展示给 LLM，措辞含混会让模型反复重试。
@Suite("标题更新工具")
@MainActor
struct TitleUpdateToolTests {

    private func makeTool(
        selected: UUID? = nil,
        failTitleUpdate: Bool = false
    ) -> (TitleUpdateTool, TitleTestDoubles.StubConversationManager) {
        let conversations = TitleTestDoubles.StubConversationManager(selected: selected)
        if let selected { conversations.appendSummary(id: selected, title: nil) }
        conversations.failTitleUpdate = failTitleUpdate
        return (TitleUpdateTool(conversations: conversations), conversations)
    }

    // MARK: - 成功

    /// 更新选中会话标题，成功时返回 ✅ 且带上新标题与会话 ID。
    @Test("更新选中会话标题返回成功文案")
    func updatesSelectedTitle() async throws {
        let id = UUID()
        let (tool, conversations) = makeTool(selected: id)

        let result = try await tool.execute(arguments: ["title": ToolArgument("新的标题")])

        #expect(result.contains("Conversation Title Updated"))
        #expect(result.contains("新的标题"))
        #expect(result.contains(id.uuidString))
        #expect(conversations.title(of: id) == "新的标题")
    }

    /// 标题首尾空白应被裁剪后再写入，避免列表里出现多余空格。
    @Test("写入前裁剪标题首尾空白")
    func trimsWhitespace() async throws {
        let id = UUID()
        let (tool, conversations) = makeTool(selected: id)

        _ = try await tool.execute(arguments: ["title": ToolArgument("  干净标题 \n")])

        #expect(conversations.title(of: id) == "干净标题")
    }

    // MARK: - 失败分支

    /// Provider 未注入时返回「服务不可用」，而不是抛错中断 Agent 回合。
    @Test("Provider 缺失时返回服务不可用")
    func reportsMissingProvider() async throws {
        let tool = TitleUpdateTool(conversations: nil)

        let result = try await tool.execute(arguments: ["title": ToolArgument("标题")])

        #expect(result.contains("Conversation service unavailable"))
        #expect(result.contains("❌"))
    }

    /// 未选中会话时返回「未找到」，与「服务不可用」区分开。
    @Test("未选中会话时返回未找到")
    func reportsNoSelection() async throws {
        let (tool, _) = makeTool(selected: nil)

        let result = try await tool.execute(arguments: ["title": ToolArgument("标题")])

        #expect(result.contains("Conversation not found or title update failed"))
    }

    /// Provider 写库失败时同样走「未找到 / 更新失败」分支，且不应抛出。
    @Test("写库失败时返回失败文案而不抛出")
    func reportsPersistenceFailure() async throws {
        let id = UUID()
        let (tool, _) = makeTool(selected: id, failTitleUpdate: true)

        let result = try await tool.execute(arguments: ["title": ToolArgument("标题")])

        #expect(result.contains("Conversation not found or title update failed"))
    }

    // MARK: - 参数校验

    /// 缺参数、空串、纯空白、非字符串都应抛 `ToolExecutionError`。
    @Test("非法 title 参数抛 ToolExecutionError")
    func rejectsInvalidArguments() async {
        let tool = TitleUpdateTool(conversations: nil)
        let cases: [[String: ToolArgument]] = [
            [:],
            ["title": ToolArgument("")],
            ["title": ToolArgument("   \n ")],
            ["title": ToolArgument(42)],
        ]

        for arguments in cases {
            await #expect(throws: ToolExecutionError.self) {
                _ = try await tool.execute(arguments: arguments)
            }
        }
    }

    // MARK: - 元信息

    /// 工具描述与 schema 是 Agent 选择工具的依据，改动需同步断言。
    @Test("工具描述与输入 schema")
    func metadata() {
        let tool = TitleUpdateTool()

        #expect(tool.name == "update_conversation_title")
        #expect(tool.description(for: .english).contains("title"))

        let schema = tool.inputSchema(for: .english)
        #expect((schema["type"] as? String) == "object")
        #expect((schema["required"] as? [String]) == ["title"])
        #expect((schema["properties"] as? [String: Any])?["title"] != nil)

        #expect(tool.permissionRiskLevel(arguments: ["title": ToolArgument("x")]) == .low)
    }

    /// `displayDescription` 面向 UI 展示，空参数时应回退到通用文案。
    @Test("displayDescription 回退与正常展示")
    func displayDescription() {
        let tool = TitleUpdateTool()

        #expect(tool.displayDescription(for: ["title": ToolArgument("新标题")]).contains("新标题"))
        #expect(tool.displayDescription(for: [:]) == "Update conversation title")
        #expect(tool.displayDescription(for: ["title": ToolArgument("  ")]) == "Update conversation title")
    }
}
