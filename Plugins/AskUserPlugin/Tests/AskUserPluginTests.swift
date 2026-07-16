import Foundation
import LumiCoreKit
import Testing
@testable import AskUserPlugin

// MARK: - Plugin Info Tests

@Suite @MainActor struct AskUserPluginInfoTests {
    
    @Test func pluginId() {
        #expect(AskUserPlugin.info.id == "plugin-ask-user")
    }
    
    @Test func pluginDisplayNameIsNotEmpty() {
        #expect(!AskUserPlugin.info.displayName.isEmpty)
    }
    
    @Test func pluginDescriptionIsNotEmpty() {
        #expect(!AskUserPlugin.info.description.isEmpty)
    }
    
    @Test func pluginOrder() {
        #expect(AskUserPlugin.info.order == 100)
    }
}

// MARK: - Plugin Properties Tests

@Suite @MainActor struct AskUserPluginPropertiesTests {
    
    @Test func pluginPolicyIsAlwaysOn() {
        #expect(AskUserPlugin.policy == .alwaysOn)
    }
    
    @Test func pluginCategoryIsGeneral() {
        #expect(AskUserPlugin.category == .general)
    }
    
    @Test func pluginIconName() {
        #expect(AskUserPlugin.iconName == "questionmark.circle.fill")
    }
}

// MARK: - Agent Tools Tests

@Suite @MainActor struct AskUserPluginAgentToolsTests {
    
    @Test func agentToolsReturnsOneTool() {
        let context = LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        )
        let tools = AskUserPlugin.agentTools(context: context)
        #expect(tools.count == 1)
    }

    @Test func agentToolsReturnsAskUserTool() {
        let context = LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        )
        let tools = AskUserPlugin.agentTools(context: context)
        #expect(tools.first?.name == "ask_user")
    }
}

// MARK: - Tool Execution Hook Tests
//
// `handleToolResult` 是 AskUserPlugin 实现 LumiToolExecutionHook 的入口。
// 内核（ChatService）在每次工具执行后会询问插件是否需要暂停 Agent 循环。
// AskUserPlugin 仅对 ask_user 工具的 pending 结果返回 true。

@Suite @MainActor struct AskUserPluginHandleToolResultTests {

    @Test func pausesForPendingAskUserResult() async {
        // ask_user 工具返回 pending 内容时，需要暂停等待用户回答
        let pending = "\(LumiAskUserMarkers.pendingPrefix)\n{\"question\":\"?\"}"
        let pause = await AskUserPlugin.handleToolResult(
            toolName: "ask_user",
            result: pending,
            conversationID: UUID()
        )
        #expect(pause == true)
    }

    @Test func doesNotPauseForOtherTools() async {
        // 非 ask_user 工具一律不处理
        let pending = "\(LumiAskUserMarkers.pendingPrefix)\n{}"
        let pause = await AskUserPlugin.handleToolResult(
            toolName: "other_tool",
            result: pending,
            conversationID: UUID()
        )
        #expect(pause == false)
    }

    @Test func doesNotPauseForNonPendingAskUserResult() async {
        // ask_user 但结果不是 pending（如已回答的普通内容）时不暂停
        let pause = await AskUserPlugin.handleToolResult(
            toolName: "ask_user",
            result: "用户回答：是",
            conversationID: UUID()
        )
        #expect(pause == false)
    }

    @Test func doesNotPauseForAskUserErrorResult() async {
        // ask_user 执行出错（errorPrefix）时不暂停
        let errorResult = "\(LumiAskUserMarkers.errorPrefix)\n{\"error\":\"bad input\"}"
        let pause = await AskUserPlugin.handleToolResult(
            toolName: "ask_user",
            result: errorResult,
            conversationID: UUID()
        )
        #expect(pause == false)
    }
}
