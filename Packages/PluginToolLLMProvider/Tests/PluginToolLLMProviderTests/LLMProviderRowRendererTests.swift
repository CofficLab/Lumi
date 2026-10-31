import Foundation
import KitAgentTool
import ProviderLLMManager
import ProviderMessageRendering
import ProviderToolManager
import SwiftUI
import Testing
@testable import PluginToolLLMProvider

/// 工具结果渲染器的匹配规则。
///
/// 渲染器必须**只**接管自己的工具：抢走别的工具的行会让授权卡片、ask_user
/// 交互等既有路径失效。
struct LLMProviderRowRendererTests {

    private func makeProposal() -> LLMProviderProposal {
        LLMProviderProposal(
            id: "custom-acme",
            displayName: "Acme Gateway",
            baseURL: "https://api.acme.example.com/v1",
            apiFormat: .openAI,
            defaultModel: "acme-large",
            models: [UserDefinedCloudModel(id: "acme-large")]
        )
    }

    private func makeToolCall(
        name: String = AddLLMProviderTool.toolName,
        content: String? = nil
    ) -> ToolCall {
        ToolCall(
            id: "call-1",
            name: name,
            arguments: "{}",
            result: content.map { ToolCallResult(content: $0) }
        )
    }

    @Test("本工具且载荷可解码时命中渲染器")
    func matchesOwnToolWithPayload() {
        let renderer = LLMProviderRowRenderer()
        let content = ProviderProposalPayload.encode(makeProposal())
        #expect(renderer.canRender(toolCall: makeToolCall(content: content)))
    }

    @Test("别的工具不命中")
    func doesNotMatchOtherTools() {
        let renderer = LLMProviderRowRenderer()
        let content = ProviderProposalPayload.encode(makeProposal())
        #expect(!renderer.canRender(toolCall: makeToolCall(name: "read_file", content: content)))
    }

    @Test("载荷缺失或不可解码时不命中")
    func doesNotMatchWithoutDecodablePayload() {
        let renderer = LLMProviderRowRenderer()
        #expect(!renderer.canRender(toolCall: makeToolCall()))
        #expect(!renderer.canRender(toolCall: makeToolCall(content: "没有载荷")))
        #expect(!renderer.canRender(toolCall: makeToolCall(content: "```json\n{坏掉的\n```")))
    }

    @Test("渲染不会因载荷损坏而崩溃")
    @MainActor
    func rendersFallbackForBrokenPayload() {
        let renderer = LLMProviderRowRenderer()
        let view = renderer.render(
            toolCall: makeToolCall(content: "没有载荷"),
            message: ToolCallRowMessageContext(
                conversationId: UUID(),
                assistantMessageId: UUID()
            )
        )
        #expect(view is AnyView)
    }

    @Test("渲染器 id 与优先级稳定")
    func hasStableIdentity() {
        #expect(LLMProviderRowRenderer.id == "llm-provider-proposal-row")
        #expect(LLMProviderRowRenderer.priority > 120, "必须高于通用授权卡片，否则会遮住授权流程")
    }
}
