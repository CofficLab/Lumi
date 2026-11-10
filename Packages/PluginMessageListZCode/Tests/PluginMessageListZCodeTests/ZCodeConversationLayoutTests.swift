import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListZCode

/// V4（ZCode）响应式布局契约测试。
///
/// 基准是 ZCode 3.15.1：
/// - 内容列宽：`packages/ui/src/v4/conversationLayout.ts`；
/// - turn 间距：`packages/ui/src/v4/ConversationTurnGroup.tsx` 的
///   `px-4 @md/conversation:px-6 pb-5` + `pt-14` / `pt-0` + `gap-5`；
/// - 用户气泡：`packages/ui/src/v4/ConversationUserInputBubble.tsx` 的
///   `@min-[624px]/conversation:max-w-xl`。
///
/// - Important: 必须使用**聊天容器宽度**，不是窗口宽度。
@Suite("ZCode 响应式布局")
struct ZCodeConversationLayoutTests {

    // MARK: - 内容列宽

    @Test("内容列宽按容器宽度分档")
    func contentWidthBuckets() {
        // < 864：整列可用。
        #expect(ZCodeConversationLayout.contentWidth(for: 390) == 390)
        #expect(ZCodeConversationLayout.contentWidth(for: 863) == 863)

        // 864 ≤ c < 1280：min(c - 96, 896)
        #expect(ZCodeConversationLayout.contentWidth(for: 864) == 768)
        #expect(ZCodeConversationLayout.contentWidth(for: 900) == 804)
        #expect(ZCodeConversationLayout.contentWidth(for: 1279) == 896)

        // c ≥ 1280：min(c - 384, 1152)
        #expect(ZCodeConversationLayout.contentWidth(for: 1280) == 896)
        #expect(ZCodeConversationLayout.contentWidth(for: 1440) == 1056)
        #expect(ZCodeConversationLayout.contentWidth(for: 1600) == 1152)
    }

    @Test("内容列宽永远不会超过容器宽度")
    func contentWidthNeverExceedsContainer() {
        for width in stride(from: CGFloat(320), through: 2000, by: 17) {
            #expect(ZCodeConversationLayout.contentWidth(for: width) <= width)
        }
    }

    // MARK: - turn 水平 padding

    @Test("turn 水平 padding 在 448 处切换")
    func turnHorizontalPaddingSwitchesAt448() {
        #expect(ZCodeConversationLayout.turnHorizontalPadding(for: 447) == 16)
        #expect(ZCodeConversationLayout.turnHorizontalPadding(for: 448) == 24)
        #expect(ZCodeConversationLayout.turnHorizontalPadding(for: 1200) == 24)
    }

    // MARK: - 用户气泡宽度

    @Test("用户气泡宽度阈值在 624 处切换")
    func userBubbleWidthThreshold() {
        // < 624：气泡可用满整列。
        #expect(ZCodeConversationLayout.userBubbleMaxWidth(containerWidth: 623, contentWidth: 623) == 623)
        // ≥ 624：最多 576。
        #expect(ZCodeConversationLayout.userBubbleMaxWidth(containerWidth: 624, contentWidth: 624) == 576)
        #expect(ZCodeConversationLayout.userBubbleMaxWidth(containerWidth: 1200, contentWidth: 1056) == 576)
    }

    @Test("用户气泡宽度不会超过内容列宽")
    func userBubbleNeverExceedsContentColumn() {
        // 窄容器下即使阈值未到，也不能超出内容列。
        #expect(
            ZCodeConversationLayout.userBubbleMaxWidth(containerWidth: 400, contentWidth: 400) == 400
        )
        #expect(
            ZCodeConversationLayout.userBubbleMaxWidth(containerWidth: 700, contentWidth: 604) <= 604
        )
    }

    // MARK: - turn 垂直间距

    @Test("含用户气泡的 turn 顶部间距 56、底部 20")
    func turnWithUserBubbleSpacing() {
        let metrics = ZCodeConversationLayout.turnSpacing(hasVisibleUserBubble: true)

        #expect(metrics.top == 56)
        #expect(metrics.bottom == 20)
    }

    @Test("没有可见用户气泡的 turn 顶部间距为 0、底部 20")
    func turnWithoutUserBubbleSpacing() {
        let metrics = ZCodeConversationLayout.turnSpacing(hasVisibleUserBubble: false)

        #expect(metrics.top == 0)
        #expect(metrics.bottom == 20)
    }

    @Test("普通 turn 与通知型 turn 的顶部间距之和不会造成 76 的空白")
    func consecutiveTurnSpacingDoesNotStack() {
        // 上一个 turn 底部 20 + 下一个 turn 顶部 0 = 20，而不是 76。
        let previous = ZCodeConversationLayout.turnSpacing(hasVisibleUserBubble: true)
        let next = ZCodeConversationLayout.turnSpacing(hasVisibleUserBubble: false)

        #expect(previous.bottom + next.top == 20)
    }

    // MARK: - 内容间距

    @Test("turn 一级内容间距是 20")
    func primaryContentSpacingIs20() {
        #expect(ZCodeConversationLayout.primarySpacing == 20)
    }

    @Test("连续工作项间距是 16")
    func workItemSpacingIs16() {
        #expect(ZCodeConversationLayout.workItemSpacing == 16)
    }

    // MARK: - 其它几何常量

    @Test("用户气泡圆角是 12 且右上角是 2")
    func userBubbleCornerRadii() {
        let radii = ZCodeConversationLayout.userBubbleCornerRadii

        #expect(radii.topLeading == 12)
        #expect(radii.topTrailing == 2)
        #expect(radii.bottomLeading == 12)
        #expect(radii.bottomTrailing == 12)
    }

    @Test("用户气泡内边距是水平 16 垂直 12")
    func userBubblePadding() {
        #expect(ZCodeConversationLayout.userBubbleHorizontalPadding == 16)
        #expect(ZCodeConversationLayout.userBubbleVerticalPadding == 12)
    }

    @Test("长文可见高度是 120 且折叠阈值在 122")
    func longTextCollapseThreshold() {
        #expect(ZCodeConversationLayout.longTextVisibleHeight == 120)
        #expect(ZCodeConversationLayout.shouldCollapse(contentHeight: 120) == false)
        #expect(ZCodeConversationLayout.shouldCollapse(contentHeight: 121) == false)
        #expect(ZCodeConversationLayout.shouldCollapse(contentHeight: 122) == true)
    }
}
