import Foundation
import KitAgentTool
import LumiUI
import ProviderAgentLoop
import ProviderConversation
import ProviderDeveloperMode
import ProviderMessage
import ProviderMessageRendering
import ProviderToolManager
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V5（ChatGPT）助手正文呈现规格测试。
///
/// 基准是 V5 方案第 2.2 / 2.5 节：
/// - 无气泡、无头像、无名称、无默认时间戳；
/// - 正文占满阅读列，目标行高 24；
/// - 轮尾操作栏**常驻占位**，hover 只改透明度，不改行高。
@Suite("V5 助手正文规格")
@MainActor
struct ChatGPTAssistantMessageViewTests {

    // MARK: - 呈现形态

    @Test("只有 V5 使用 ChatGPT 助手呈现")
    func routesOnlyChatGPTVerbosity() {
        for verbosity in ResponseVerbosity.allCases {
            #expect(
                ChatGPTAssistantTextStyle.usesChatGPTPresentation(verbosity: verbosity)
                    == (verbosity == .chatGPT)
            )
        }
    }

    @Test("助手正文没有气泡、头像、名称与默认时间戳")
    func assistantBodyHasNoChrome() {
        #expect(ChatGPTAssistantTextStyle.hasBubble == false)
        #expect(ChatGPTAssistantTextStyle.hasAvatar == false)
        #expect(ChatGPTAssistantTextStyle.hasSenderName == false)
        #expect(ChatGPTAssistantTextStyle.showsDefaultTimestamp == false)
        #expect(ChatGPTAssistantTextStyle.fillsContentColumn == true)
    }

    @Test("正文 15、目标行高 24，工作项间距 12")
    func typographyAndSpacing() {
        #expect(ChatGPTAssistantTextStyle.fontSize == 15)
        #expect(ChatGPTAssistantTextStyle.targetLineHeight == 24)
        #expect(ChatGPTAssistantTextStyle.workItemSpacing == 12)
    }

    @Test("正文 lineSpacing 由 NSFont 实际行高换算，不等于目标行高")
    func lineSpacingDerivedFromFont() {
        #expect(ChatGPTAssistantTextStyle.lineSpacing > 0)
        #expect(ChatGPTAssistantTextStyle.lineSpacing != ChatGPTAssistantTextStyle.targetLineHeight)
    }

    @Test("流式正文没有 cursor、淡入与脉冲")
    func streamingHasNoDecorativeEffects() {
        #expect(ChatGPTAssistantTextStyle.hasStreamingCursor == false)
        #expect(ChatGPTAssistantTextStyle.hasStreamingFadeIn == false)
        #expect(ChatGPTAssistantTextStyle.hasStreamingPulse == false)
    }

    // MARK: - 轮尾操作栏

    @Test("操作栏占位与 hover 无关，只看轮尾 + 已完成 + 有内容")
    func actionBarSlotIgnoresHover() {
        let context = MessageTurnPresentationContext(
            turnKey: "turn:1",
            agentTurnID: nil,
            isTailAssistantText: true,
            isRunning: false,
            assistantCopyText: "回答",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        // 占位：与 hover 无关，因此两种 hover 状态都占位。
        #expect(ChatGPTAssistantTextStyle.shouldReserveActionBarSlot(context: context))

        // 非轮尾不占位。
        let notTail = MessageTurnPresentationContext(
            turnKey: "turn:1",
            agentTurnID: nil,
            isTailAssistantText: false,
            isRunning: false,
            assistantCopyText: "回答",
            completedAt: nil
        )
        #expect(!ChatGPTAssistantTextStyle.shouldReserveActionBarSlot(context: notTail))

        // 运行中不占位。
        let running = MessageTurnPresentationContext(
            turnKey: "turn:1",
            agentTurnID: nil,
            isTailAssistantText: true,
            isRunning: true,
            assistantCopyText: "回答",
            completedAt: nil
        )
        #expect(!ChatGPTAssistantTextStyle.shouldReserveActionBarSlot(context: running))

        // 没有 context（V1–V4）不占位。
        #expect(!ChatGPTAssistantTextStyle.shouldReserveActionBarSlot(context: nil))
    }

    @Test("操作栏显示需要轮尾 + 已完成 + hover 三者同时成立")
    func actionBarVisibilityRequiresHover() {
        #expect(ChatGPTAssistantTextStyle.shouldShowActionBar(
            isTailAssistantText: true,
            isRunning: false,
            isHovered: true
        ))
        // 没有 hover 不显示。
        #expect(!ChatGPTAssistantTextStyle.shouldShowActionBar(
            isTailAssistantText: true,
            isRunning: false,
            isHovered: false
        ))
        // 运行中不显示。
        #expect(!ChatGPTAssistantTextStyle.shouldShowActionBar(
            isTailAssistantText: true,
            isRunning: true,
            isHovered: true
        ))
        // 不是轮尾不显示。
        #expect(!ChatGPTAssistantTextStyle.shouldShowActionBar(
            isTailAssistantText: false,
            isRunning: false,
            isHovered: true
        ))
    }

    @Test("没有 context 时操作栏永远不显示")
    func actionBarHiddenWithoutContext() {
        #expect(!ChatGPTAssistantTextStyle.shouldShowActionBar(context: nil, isHovered: true))
    }

    @Test("复制文本为空时不显示复制按钮")
    func copyButtonNeedsText() {
        #expect(!ChatGPTAssistantTextStyle.shouldShowCopyButton(copyText: ""))
        #expect(ChatGPTAssistantTextStyle.shouldShowCopyButton(copyText: "回答"))
    }

    @Test("操作栏几何符合 V5 token")
    func actionBarMetrics() {
        #expect(ChatGPTAssistantTextStyle.actionBarSlotHeight == 32)
        #expect(ChatGPTAssistantTextStyle.actionButtonSize == 28)
    }

    // MARK: - 重试

    @Test("成功回复不显示重试")
    func successfulReplyHasNoRetry() {
        let capability = ChatGPTAssistantStubCapability(retryableTurnIDs: [])
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "好的"
        )

        #expect(ChatGPTAssistantTextStyle.retryableTurnID(
            message: message,
            capability: capability
        ) == nil)
    }

    @Test("只有真实可重试的失败回合才有重试")
    func onlyRealFailedTurnCanRetry() {
        let turnID = UUID()
        let capability = ChatGPTAssistantStubCapability(retryableTurnIDs: [turnID])
        let failed = Message(
            conversationID: UUID(),
            role: .error,
            content: "失败",
            turnID: turnID,
            isError: true
        )

        #expect(ChatGPTAssistantTextStyle.retryableTurnID(
            message: failed,
            capability: capability
        ) == turnID)
    }

    @Test("回合已失效时没有重试")
    func staleTurnHasNoRetry() {
        let turnID = UUID()
        let capability = ChatGPTAssistantStubCapability(retryableTurnIDs: [])
        let failed = Message(
            conversationID: UUID(),
            role: .error,
            content: "失败",
            turnID: turnID,
            isError: true
        )

        #expect(ChatGPTAssistantTextStyle.retryableTurnID(
            message: failed,
            capability: capability
        ) == nil)
    }
}

/// 最小可用的能力替身：只关心重试判定。
@MainActor
final class ChatGPTAssistantStubCapability: MessageRendererCapability {
    private let retryableTurnIDs: Set<UUID>

    init(retryableTurnIDs: Set<UUID>) {
        self.retryableTurnIDs = retryableTurnIDs
    }

    func toolCallResult(
        for toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult? {
        nil
    }

    func resendMessage(content: String, conversationID: UUID) async {}

    func canRetryTurn(turnID: UUID, conversationID: UUID) -> Bool {
        retryableTurnIDs.contains(turnID)
    }

    func retryTurn(turnID: UUID, conversationID: UUID) async {}

    func toolCallRenderer(for toolCall: ToolCall) -> (any ToolCallRowRenderer)? { nil }

    func makeToolJobActivityModel(
        toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) -> ToolJobActivityModel {
        ToolJobActivityModel(
            manager: nil,
            toolCallID: toolCallID,
            conversationID: conversationID,
            turnID: turnID
        )
    }

    var isDeveloperModeEnabled: Bool { false }

    func addDeveloperModeObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle {
        NoopDeveloperModeProvidingObserverHandle()
    }
}
