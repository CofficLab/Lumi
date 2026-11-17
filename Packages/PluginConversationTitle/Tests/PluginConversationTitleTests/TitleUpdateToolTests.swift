import Foundation
import KitAgentTool
import ProviderConversation
import Testing

@testable import PluginConversationTitle

/// `TitleUpdateTool`（Agent 工具 `update_conversation_title`）的行为测试。
///
/// 失败分支统一抛出 `ToolExecutionError`，由包装层标记 `isError`；
/// 工具不再用返回文案表达失败。
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

    /// Provider 未注入时抛出「服务不可用」，由包装层标记 isError。
    @Test("Provider 缺失时抛出服务不可用")
    func reportsMissingProvider() async {
        let tool = TitleUpdateTool(conversations: nil)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: ["title": ToolArgument("标题")])
        }
    }

    /// 未选中会话时抛出「未找到」，与「服务不可用」区分开。
    @Test("未选中会话时抛出未找到")
    func reportsNoSelection() async {
        let (tool, _) = makeTool(selected: nil)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: ["title": ToolArgument("标题")])
        }
    }

    /// Provider 写库失败时同样抛出「未找到 / 更新失败」。
    @Test("写库失败时抛出更新失败")
    func reportsPersistenceFailure() async {
        let id = UUID()
        let (tool, _) = makeTool(selected: id, failTitleUpdate: true)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: ["title": ToolArgument("标题")])
        }
    }

    // MARK: - 结构化结果（executeResult）

    /// 回归 #651：带 context 的结构化入口在写库失败时必须抛出，由宿主包装层
    /// 标记 `isError == true`；不得把失败文案包成 `isError == false` 的成功结果，
    /// 否则 GUI 显示成功、ACP 发送 completed。
    @Test("executeResult 写库失败时抛出而非返回成功结果")
    func executeResultThrowsOnPersistenceFailure() async {
        let id = UUID()
        let (tool, _) = makeTool(selected: id, failTitleUpdate: true)
        let context = ToolExecutionContext(jobID: "job-\(id.uuidString)", conversationID: id)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(
                context: context,
                arguments: ["title": ToolArgument("标题")]
            )
        }
    }

    /// 回归 #651：成功路径的结构化结果保持 `isError == false`，与失败路径形成对照。
    @Test("executeResult 成功时不带错误标记")
    func executeResultSuccessIsNotError() async throws {
        let id = UUID()
        let (tool, _) = makeTool(selected: id)
        let context = ToolExecutionContext(jobID: "job-\(id.uuidString)", conversationID: id)

        let result = try await tool.executeResult(
            context: context,
            arguments: ["title": ToolArgument("新标题")]
        )
        #expect(result.isError == false)
        #expect(result.content.contains("Conversation Title Updated"))
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
