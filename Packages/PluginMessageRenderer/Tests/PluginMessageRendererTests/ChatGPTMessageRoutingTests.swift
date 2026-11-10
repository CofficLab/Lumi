import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V5（ChatGPT）渲染路由矩阵测试。
///
/// 基准是 V5 方案第 2 节的路由矩阵：
///
/// | 输入 | 必须得到 |
/// |---|---|
/// | user | ChatGPT 右侧气泡 |
/// | 普通 assistant | 无气泡正文 |
/// | tool-step-group / turn-activity | ChatGPT 工具工作组 |
/// | error / isError | 内联错误 |
/// | status / system / compact / retry / model switch | 低强调 timeline marker |
/// | 独立 tool | 安全工具呈现 |
/// | default / 未知 renderKind | 无旧 chrome 的 Markdown 兜底 |
/// | `preferredRendererID` | 仍选指定 renderer，不被 V5 截获 |
@Suite("V5 渲染路由矩阵")
@MainActor
struct ChatGPTMessageRoutingTests {

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

    // MARK: - renderer 选择

    @Test("V5 下各角色仍由核心 renderer 接管")
    func rendererSelectionIsUnchangedByVerbosity() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))

        // verbosity 不参与 renderer 的**选择**，只在 render 内部决定呈现。
        #expect(manager.renderer(for: message(role: .user))?.id == "core-user-message")
        #expect(manager.renderer(for: message(role: .assistant))?.id == "core-assistant-message")
        #expect(manager.renderer(for: message(role: .system))?.id == "core-system-message")
        #expect(manager.renderer(for: message(role: .tool))?.id == "core-tool-message")
        #expect(manager.renderer(for: message(role: .error))?.id == "core-error-message")
        #expect(manager.renderer(for: message(role: .status))?.id == "core-status-message")
    }

    @Test("preferredRendererID 仍然优先，V5 不截获")
    func preferredRendererIDWins() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))

        let custom = MessageRendererItem(
            id: "custom-provider-renderer",
            order: 999,
            canRender: { _ in true },
            render: { _, _ in AnyView(EmptyView()) }
        )
        manager.register(custom)

        let target = message(role: .user, preferredRendererID: "custom-provider-renderer")
        #expect(manager.renderer(for: target)?.id == "custom-provider-renderer")
    }

    // MARK: - 呈现类型

    @Test("V5 的助手正文使用 ChatGPT 视图而非 legacy")
    func assistantUsesChatGPTViewForV5() {
        // 通过类型判定验证分支：V5 走 ChatGPTAssistantMessageView。
        #expect(ChatGPTAssistantTextStyle.usesChatGPTPresentation(verbosity: .chatGPT))
        #expect(!ChatGPTAssistantTextStyle.usesChatGPTPresentation(verbosity: .zcode))
        #expect(!ChatGPTAssistantTextStyle.usesChatGPTPresentation(verbosity: .standard))
        #expect(!ChatGPTAssistantTextStyle.usesChatGPTPresentation(verbosity: .detailed))
        #expect(!ChatGPTAssistantTextStyle.usesChatGPTPresentation(verbosity: .brief))
    }

    @Test("V5 的用户消息使用 ChatGPT 气泡")
    func userUsesChatGPTBubbleForV5() {
        for verbosity in ResponseVerbosity.allCases {
            #expect(
                ChatGPTUserMessageView.usesChatGPTPresentation(verbosity: verbosity)
                    == (verbosity == .chatGPT)
            )
        }
    }

    @Test("timeline marker 是 V5 的系统事件呈现")
    func timelineMarkerHandlesSystemEvents() {
        let compaction = message(
            role: .system,
            content: "压缩完成",
            renderKind: MessageTimelineEvent.contextCompactionRenderKind
        )
        let retry = message(
            role: .status,
            content: "重试",
            renderKind: MessageTimelineEvent.agentLoopRetryRenderKind
        )
        // model-switch 必须带真实的目标模型名，否则没有可显示的内容 ——
        // 字段缺失时宁可不显示，也不伪造。
        let modelSwitch = Message(
            id: UUID(),
            conversationID: UUID(),
            role: .system,
            content: "",
            metadata: [
                MessageTimelineEvent.modelSwitchedToModelNameKey: "gpt-5.5",
            ],
            renderKind: MessageTimelineEvent.modelSwitchedRenderKind
        )

        // 都必须落到 V5 的 timeline marker。
        #expect(ChatGPTTimelineMarkerStyle.shouldRender(message: compaction))
        #expect(ChatGPTTimelineMarkerStyle.shouldRender(message: retry))
        #expect(ChatGPTTimelineMarkerStyle.shouldRender(message: modelSwitch))
    }

    @Test("独立工具消息保持工具呈现，不落到 timeline marker")
    func standaloneToolKeepsToolRendering() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))

        #expect(manager.renderer(for: message(role: .tool))?.id == "core-tool-message")
    }

    @Test("tool-step-group 走助手分支，由 ChatGPT 助手视图承载工具组")
    func toolStepGroupUsesAssistantRenderer() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))

        #expect(manager.renderer(for: message(role: .assistant, renderKind: "tool-step-group"))?.id
            == "core-tool-step-group")
        #expect(manager.renderer(for: message(role: .assistant, renderKind: "turn-activity"))?.id
            == "core-tool-step-group")
    }

    @Test("错误消息在 V5 下走内联错误")
    func errorUsesInlineErrorForV5() throws {
        let kernel = try makeKernel()
        let manager = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))

        #expect(manager.renderer(for: message(role: .error))?.id == "core-error-message")
        #expect(manager.renderer(for: message(role: .assistant, isError: true))?.id == "core-error-message")
    }
}
