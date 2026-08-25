import Foundation
import Testing
import KitAgentTool
import ProviderConversation
import ProviderMessage

@testable import PluginConversationTitle

@Suite("ConversationTitlePlugin")
@MainActor
struct ConversationTitlePluginTests {
    @Test("标题生成：normalizeTitle 清理引号与换行")
    func normalizeTitle() {
        #expect(AutoConversationTitleService.normalizeTitle("  你好世界  ") == "你好世界")
        #expect(AutoConversationTitleService.normalizeTitle("\"带引号\"") == "带引号")
        #expect(AutoConversationTitleService.normalizeTitle("第一行\n第二行") == "第一行")
        let long = String(repeating: "字", count: 50)
        #expect(AutoConversationTitleService.normalizeTitle(long).count == 40)
    }

    @Test("占位标题：长消息截断到 40 字符")
    func placeholderTitle() {
        #expect(AutoConversationTitleService.placeholderTitle(forFirstUserMessage: "hi") == "hi")
        let long = String(repeating: "长", count: 45)
        let title = AutoConversationTitleService.placeholderTitle(forFirstUserMessage: long)
        #expect(title.count == 41) // 40 + …
        #expect(title.hasSuffix("…"))
    }

    @Test("标题更新工具：更新选中会话标题")
    func updateToolUpdatesTitle() async throws {
        let conversations = DefaultConversationManager()
        let id = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
        conversations.selectConversation(id: id)

        let tool = ConversationTitleUpdateTool(conversations: conversations)
        let result = try await tool.execute(arguments: ["title": ToolArgument("我的新标题")])
        #expect(result.contains("Conversation Title Updated"))
        #expect(conversations.currentTitle == "我的新标题")
    }

    @Test("标题更新工具：缺参数抛错")
    func updateToolMissingArgument() async {
        let tool = ConversationTitleUpdateTool(conversations: nil)
        do {
            _ = try await tool.execute(arguments: [:])
            Issue.record("应抛错")
        } catch {
            #expect(error is ToolExecutionError)
        }
    }
}
