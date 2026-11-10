import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderConversation
import ProviderDeveloperMode
import ProviderMessage
import ProviderMessageRendering
import ProviderToolManager
import SwiftUI
import Testing
@testable import PluginMessageRenderer

@MainActor
private final class ChatGPTStubRendererCapability: MessageRendererCapability {
    private(set) var resendRequests: [(content: String, conversationID: UUID)] = []

    func toolCallResult(
        for toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult? {
        nil
    }

    func resendMessage(content: String, conversationID: UUID) async {
        resendRequests.append((content, conversationID))
    }

    func canRetryTurn(turnID: UUID, conversationID: UUID) -> Bool { false }

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

@Suite("ChatGPT 用户消息")
@MainActor
struct ChatGPTUserMessageViewTests {
    @Test("只有 V5 使用 ChatGPT 用户消息呈现")
    func routesOnlyChatGPTVerbosity() {
        for verbosity in ResponseVerbosity.allCases {
            #expect(
                ChatGPTUserMessageView.usesChatGPTPresentation(verbosity: verbosity)
                    == (verbosity == .chatGPT)
            )
        }
    }

    @Test("短文本按理想宽度收缩，长文本受气泡最大宽约束")
    func bubbleWidthHugsShortTextAndConstrainsLongText() {
        #expect(ChatGPTUserMessageLayout.constrainedWidth(idealWidth: 48, availableWidth: 560) == 48)
        #expect(ChatGPTUserMessageLayout.constrainedWidth(idealWidth: 900, availableWidth: 560) == 560)
        #expect(ChatGPTUserMessageLayout.maximumBubbleWidth(for: 768) == 560)
    }

    @Test("长 URL 自然换行且不进入 120pt 折叠")
    func longURLWrapsWithoutLegacyCollapse() {
        let content = String(repeating: "https://example.com/averylongpath/", count: 20)
        let blocks = CollapsedContentBlockMetadata.normalizedBlocks(
            from: [:],
            contentLength: content.count
        )

        #expect(ChatGPTUserMessageView.contentPresentation(for: blocks) == .plainText)
        #expect(ChatGPTUserBubbleStyle.bodyLineLimit == nil)
        #expect(ChatGPTUserBubbleStyle.collapsesLongPlainText == false)
    }

    @Test("collapsed content metadata 仍使用 chip 呈现")
    func collapsedMetadataUsesChips() {
        let content = "before pasted after"
        let metadata = CollapsedContentBlockMetadata.encodeCollapsedBlocks([
            CollapsedContentBlock(start: 7, length: 6, title: "Pasted text"),
        ])
        let blocks = CollapsedContentBlockMetadata.normalizedBlocks(
            from: metadata,
            contentLength: content.count
        )

        #expect(blocks.count == 1)
        #expect(ChatGPTUserMessageView.contentPresentation(for: blocks) == .collapsedChips)
    }

    @Test("只有附件时不产生空气泡")
    func attachmentOnlyMessageHasNoEmptyBubble() {
        #expect(ChatGPTUserBubbleStyle.hasVisibleBubble(content: "", hasAttachments: true) == false)
        #expect(ChatGPTUserBubbleStyle.hasVisibleBubble(content: "  \n", hasAttachments: true) == false)
        #expect(ChatGPTUserBubbleStyle.hasVisibleBubble(content: "Hello", hasAttachments: true))
    }

    @Test("复制使用原始正文")
    func copyUsesRawContent() {
        let content = "  raw content\nsecond line  "
        #expect(ChatGPTUserBubbleStyle.copyText(for: content) == content)
    }

    @Test("再次发送只调用一次现有 capability 并保留原文和会话")
    func resendSendsExactlyOneRequest() async {
        let capability = ChatGPTStubRendererCapability()
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID,
            role: .user,
            content: "  send this again  "
        )

        await ChatGPTUserMessageActions.resend(message: message, capability: capability)

        #expect(capability.resendRequests.count == 1)
        #expect(capability.resendRequests.first?.content == message.content)
        #expect(capability.resendRequests.first?.conversationID == conversationID)
    }

    @Test("气泡与操作按钮使用 V5 几何")
    func bubbleAndActionMetrics() {
        #expect(ChatGPTUserBubbleStyle.cornerRadius == 18)
        #expect(ChatGPTUserBubbleStyle.horizontalPadding == 16)
        #expect(ChatGPTUserBubbleStyle.verticalPadding == 10)
        #expect(ChatGPTUserBubbleStyle.bodyLineHeight == 24)
        #expect(ChatGPTUserBubbleStyle.actionButtonSize == 28)
        #expect(ChatGPTUserBubbleStyle.actionBarHeight == 32)
    }
}
