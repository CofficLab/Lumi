import Foundation
import KernelCore
import KitAgentTool
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// 验证 PluginMessageRenderer 的 10 个内置渲染器注册与匹配逻辑。
@Suite("MessageRendererPlugin")
@MainActor
struct MessageRendererPluginTests {
    @Test("工具调用参数保留真实 JSON 与历史异常内容")
    func formatsToolCallArguments() {
        #expect(MessageViewHelpers.formatToolCallArguments("  {}  ") == nil)
        #expect(MessageViewHelpers.formatToolCallArguments("{\"path\":\"/tmp/a\"}")?.contains("\"path\"") == true)
        #expect(MessageViewHelpers.formatToolCallArguments("{}{\"scope\":\"global\"}")?.contains("\"scope\"") == true)
        #expect(MessageViewHelpers.formatToolCallArguments("{}\n{\"path\":\"/tmp/a\"}")?.contains("\"path\"") == true)
    }

    @Test("已有最终结果的旧 pending 工具调用不重复显示授权")
    func completedPendingToolCallDoesNotRenderApproval() {
        let renderer = ToolApprovalRowRenderer()
        let completed = ToolCall(
            id: "call-completed",
            name: "read",
            arguments: "{}",
            authorizationState: .pendingAuthorization,
            result: ToolCallResult(content: "done")
        )
        let waiting = ToolCall(
            id: "call-waiting",
            name: "read",
            arguments: "{}",
            authorizationState: .pendingAuthorization,
            result: ToolCallResult(content: "approval", awaitingUserResponse: true)
        )

        #expect(renderer.canRender(toolCall: completed) == false)
        #expect(renderer.canRender(toolCall: waiting) == true)
    }

    private func makeKernel() throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any MessageRenderingProviding).self, DefaultMessageRenderingProviding())
        try kernel.start(plugins: [MessageRendererPlugin()])
        return kernel
    }

    private func message(
        role: MessageRole,
        content: String = "",
        isError: Bool = false,
        renderKind: String? = nil,
        preferredRendererID: String? = nil
    ) -> Message {
        Message(
            id: UUID(),
            conversationID: UUID(),
            role: role,
            content: content,
            isError: isError,
            renderKind: renderKind,
            preferredRendererID: preferredRendererID
        )
    }

    @Test("10 个内置渲染器全部注册")
    func registersAllBuiltinRenderers() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))
        #expect(manager.allRenderers.count == 9)
        let ids = Set(manager.allRenderers.map(\.id))
        #expect(ids.contains("core-user-message"))
        #expect(ids.contains("core-assistant-message"))
        #expect(ids.contains("core-system-message"))
        #expect(ids.contains("core-error-message"))
        #expect(ids.contains("core-tool-message"))
        #expect(ids.contains("core-status-message"))
        #expect(ids.contains("core-turn-completed"))
        #expect(ids.contains("core-tool-step-group"))
        #expect(ids.contains("core-default-markdown"))
    }

    @Test("按 role 分发到对应渲染器")
    func dispatchesByRole() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))

        #expect(manager.renderer(for: message(role: .user))?.id == "core-user-message")
        #expect(manager.renderer(for: message(role: .assistant))?.id == "core-assistant-message")
        #expect(manager.renderer(for: message(role: .system))?.id == "core-system-message")
        #expect(manager.renderer(for: message(role: .tool))?.id == "core-tool-message")
        #expect(manager.renderer(for: message(role: .error))?.id == "core-error-message")
        #expect(manager.renderer(for: message(role: .status))?.id == "core-status-message")
    }

    @Test("turn-completed 与 tool-step-group 特殊渲染")
    func dispatchesSpecialKinds() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))

        // turn-completed：renderKind 标记或正文标记
        #expect(manager.renderer(for: message(role: .assistant, renderKind: "turn-completed"))?.id == "core-turn-completed")
        #expect(manager.renderer(for: message(role: .assistant, content: "__lumi_turn_completed__"))?.id == "core-turn-completed")
        // tool-step-group
        #expect(manager.renderer(for: message(role: .assistant, renderKind: "tool-step-group"))?.id == "core-tool-step-group")
        // 错误消息
        #expect(manager.renderer(for: message(role: .assistant, isError: true))?.id == "core-error-message")
    }

    @Test("preferredRendererID 显式路由优先")
    func prefersExplicitRenderer() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))
        // 默认链会命中 order 最高的 turn-completed（renderKind 匹配）；
        // preferred 指向 canRender 同样通过的 error 渲染器 → 应显式路由到 error。
        let msg = message(role: .assistant, isError: true, renderKind: "turn-completed")
        #expect(manager.renderer(for: msg)?.id == "core-turn-completed")
        let routed = Message(
            id: UUID(),
            conversationID: UUID(),
            role: .assistant,
            content: "",
            isError: true,
            renderKind: "turn-completed",
            preferredRendererID: "core-error-message"
        )
        #expect(manager.renderer(for: routed)?.id == "core-error-message")
    }

    @Test("兜底渲染器接管未匹配消息")
    func fallbackRenderer() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))
        let custom = Message(
            id: UUID(),
            conversationID: UUID(),
            role: .assistant,
            content: "anything"
        )
        _ = custom
        #expect(manager.renderer(for: message(role: .assistant, content: "未知内容"))?.id == "core-assistant-message")
    }

    @Test("渲染闭包返回可渲染视图")
    func renderClosureProducesView() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))
        let renderer = try #require(manager.renderer(for: message(role: .user, content: "hi")))
        let view = renderer.render(message(role: .user, content: "hi"), .standard)
        #expect(view is AnyView)
    }
}
