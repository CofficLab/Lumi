import Foundation
import LumiUI
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V5（ChatGPT）工具工作组呈现规格测试。
///
/// 基准是 V5 方案第 2.6 节：
/// - 工具组显示真实工具数与状态；
/// - **等待授权的工具必须可见且可交互**，不得因默认折叠被隐藏。
@Suite("V5 工具工作组规格")
struct ChatGPTToolWorkHistoryViewTests {

    private func toolCall(
        name: String,
        authorizationState: String? = nil,
        awaitingUserResponse: Bool = false
    ) -> MessageToolCall {
        MessageToolCall(
            id: "call-\(name)-\(authorizationState ?? "none")-\(awaitingUserResponse)",
            name: name,
            arguments: "{}",
            result: awaitingUserResponse
                ? MessageToolResult(
                    content: "等待授权",
                    awaitingUserResponse: true
                )
                : nil,
            authorizationState: authorizationState
        )
    }

    // MARK: - 分组

    @Test("单个工具不形成父分组")
    func singleToolDoesNotGroup() {
        #expect(!ChatGPTToolWorkHistoryStyle.shouldGroup(tools: [toolCall(name: "explore")]))
        #expect(!ChatGPTToolWorkHistoryStyle.shouldGroup(tools: []))
    }

    @Test("两个及以上同类工具形成父分组")
    func multipleGroupableToolsGroup() {
        let tools = [
            toolCall(name: "explore"),
            toolCall(name: "execute"),
        ]
        #expect(ChatGPTToolWorkHistoryStyle.shouldGroup(tools: tools))
    }

    @Test("混入非分组家族时不形成父分组")
    func mixedFamilyDoesNotGroup() {
        let tools = [
            toolCall(name: "explore"),
            toolCall(name: "write"),
        ]
        #expect(!ChatGPTToolWorkHistoryStyle.shouldGroup(tools: tools))
    }

    @Test("工具名大小写不敏感")
    func toolNameMatchingIsCaseInsensitive() {
        #expect(ChatGPTToolWorkHistoryStyle.isGroupableFamily(toolName: "EXPLORE"))
        #expect(ChatGPTToolWorkHistoryStyle.isGroupableFamily(toolName: "Terminal"))
        #expect(!ChatGPTToolWorkHistoryStyle.isGroupableFamily(toolName: "write"))
    }

    // MARK: - 授权可见性

    @Test("等待用户响应的工具必须被识别")
    func detectsAwaitingUserResponse() {
        let tools = [toolCall(name: "write", awaitingUserResponse: true)]
        #expect(ChatGPTToolWorkHistoryStyle.containsPendingAuthorization(tools: tools))
    }

    @Test("待授权状态的工具必须被识别")
    func detectsPendingAuthorizationState() {
        let tools = [toolCall(name: "write", authorizationState: "pendingAuthorization")]
        #expect(ChatGPTToolWorkHistoryStyle.containsPendingAuthorization(tools: tools))
    }

    @Test("没有待授权工具时不默认展开")
    func doesNotExpandWithoutPendingAuthorization() {
        let tools = [
            toolCall(name: "explore"),
            toolCall(name: "execute"),
        ]
        #expect(!ChatGPTToolWorkHistoryStyle.containsPendingAuthorization(tools: tools))
        #expect(!ChatGPTToolWorkHistoryStyle.defaultExpanded(tools: tools))
    }

    @Test("有待授权工具时默认展开，不隐藏授权")
    func expandsWhenAuthorizationPending() {
        let tools = [
            toolCall(name: "explore"),
            toolCall(name: "write", authorizationState: "pendingAuthorization"),
        ]
        #expect(ChatGPTToolWorkHistoryStyle.containsPendingAuthorization(tools: tools))
        #expect(ChatGPTToolWorkHistoryStyle.defaultExpanded(tools: tools))
    }

    // MARK: - 摘要

    @Test("摘要包含真实工具名与真实数量")
    func summaryShowsRealNamesAndCount() {
        let text = ChatGPTToolWorkHistoryStyle.summaryText(
            toolNames: ["explore", "execute"],
            toolCount: 2
        )
        #expect(text.contains("explore"))
        #expect(text.contains("execute"))
        #expect(text.contains("2"))
    }

    @Test("没有工具名时摘要为空")
    func summaryEmptyWithoutNames() {
        #expect(ChatGPTToolWorkHistoryStyle.summaryText(toolNames: [], toolCount: 0).isEmpty)
    }

    // MARK: - 几何

    @Test("几何符合 V5 token")
    func metrics() {
        #expect(ChatGPTToolWorkHistoryStyle.summaryFontSize == 13)
        #expect(ChatGPTToolWorkHistoryStyle.iconSize == 16)
        #expect(ChatGPTToolWorkHistoryStyle.itemSpacing == 8)
        #expect(ChatGPTToolWorkHistoryStyle.expandedContentSpacing == 8)
    }
}
