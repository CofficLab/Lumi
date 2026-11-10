import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListChatGPT

@Suite("ChatGPT 响应式布局")
struct ChatGPTConversationLayoutTests {
    @Test("水平 padding 在 480 处切换")
    func horizontalPaddingSwitchesAt480() {
        #expect(ChatGPTConversationLayout.horizontalPadding(for: 390) == 16)
        #expect(ChatGPTConversationLayout.horizontalPadding(for: 479) == 16)
        #expect(ChatGPTConversationLayout.horizontalPadding(for: 480) == 24)
        #expect(ChatGPTConversationLayout.horizontalPadding(for: 900) == 24)
    }

    @Test("内容列按容器宽度计算且最多 768")
    func contentWidthBuckets() {
        #expect(ChatGPTConversationLayout.contentWidth(for: 390) == 358)
        #expect(ChatGPTConversationLayout.contentWidth(for: 479) == 447)
        #expect(ChatGPTConversationLayout.contentWidth(for: 480) == 432)
        #expect(ChatGPTConversationLayout.contentWidth(for: 900) == 768)
        #expect(ChatGPTConversationLayout.contentWidth(for: 1440) == 768)
    }

    @Test("非法与非有限容器宽度返回零")
    func invalidContainerWidthsReturnZero() {
        for width in [CGFloat.zero, -10, .nan, .infinity, -CGFloat.infinity] {
            #expect(ChatGPTConversationLayout.contentWidth(for: width) == 0)
        }
    }

    @Test("用户气泡窄列 92%、宽列 80%，且最多 560")
    func userBubbleWidthRules() {
        let narrow = ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: 358)
        #expect(abs(narrow - 358 * 0.92) < 0.0001)
        #expect(ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: 768) == 560)
        #expect(ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: 100) == 92)
        #expect(ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: 479) == 479 * 0.92)
        #expect(ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: 480) == 384)
    }

    @Test("用户气泡永不超过内容列或产生负宽")
    func userBubbleNeverExceedsContentColumn() {
        #expect(ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: 432) == 432 * 0.92)
        #expect(ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: 0) == 0)
        #expect(ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: -10) == 0)
        #expect(ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: .nan) == 0)
        #expect(ChatGPTConversationLayout.userBubbleMaxWidth(contentWidth: .infinity) == 0)
    }

    @Test("turn 与列表间距符合 V5 token")
    func spacingTokens() {
        #expect(ChatGPTConversationLayout.turnSpacing == 32)
        #expect(ChatGPTConversationLayout.userAssistantSpacing == 16)
        #expect(ChatGPTConversationLayout.workItemSpacing == 12)
        #expect(ChatGPTConversationLayout.listTopSpacing == 16)
        #expect(ChatGPTConversationLayout.listBottomSpacing == 24)
        #expect(ChatGPTConversationLayout.bottomAnchorSpacing == 16)
    }

    @Test("用户气泡几何与正文行高符合 V5 token")
    func userBubbleTokens() {
        #expect(ChatGPTConversationLayout.userBubbleCornerRadius == 18)
        #expect(ChatGPTConversationLayout.userBubbleHorizontalPadding == 16)
        #expect(ChatGPTConversationLayout.userBubbleVerticalPadding == 10)
        #expect(ChatGPTConversationLayout.bodyLineHeight == 24)
    }

    @Test("操作栏、回到底部和底部跟随几何符合 V5 token")
    func actionAndScrollTokens() {
        #expect(ChatGPTConversationLayout.actionButtonSize == 28)
        #expect(ChatGPTConversationLayout.actionBarHeight == 32)
        #expect(ChatGPTConversationLayout.backToBottomButtonSize == 32)
        #expect(ChatGPTConversationLayout.backToBottomOffset == 16)
        #expect(ChatGPTConversationLayout.bottomTolerance == 48)
    }
}
