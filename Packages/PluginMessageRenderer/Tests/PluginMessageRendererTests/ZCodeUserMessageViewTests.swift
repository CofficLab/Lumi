import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageRenderer

/// V4（ZCode）用户气泡契约测试。
///
/// 基准是 ZCode 3.15.1：
/// - `packages/ui/src/v4/ConversationUserInputBubble.tsx`：
///   `rounded-xl rounded-tr-xs border border-border bg-surface px-4 py-3
///   text-ui-base text-foreground @min-[624px]/conversation:max-w-xl`；
/// - `packages/ui/src/v4/ConversationUserInputBody.tsx`：
///   `COLLAPSED_USER_INPUT_CONTENT_MAX_HEIGHT_PX = 120`、
///   `USER_INPUT_CONTENT_OVERFLOW_TOLERANCE_PX = 1`；
/// - `packages/ui/src/v4/ConversationRowView.tsx` 的 `CopyRowAction`：
///   成功后 1200ms 恢复。
@Suite("ZCode 用户气泡")
struct ZCodeUserMessageViewTests {

    // MARK: - 几何

    @Test("圆角是四角 12、右上角 2")
    func cornerRadiiMatchZCode() {
        let radii = ZCodeUserBubbleStyle.cornerRadii

        #expect(radii.topLeading == 12)
        #expect(radii.topTrailing == 2)
        #expect(radii.bottomLeading == 12)
        #expect(radii.bottomTrailing == 12)
    }

    @Test("内边距是水平 16、垂直 12")
    func paddingMatchesZCode() {
        #expect(ZCodeUserBubbleStyle.horizontalPadding == 16)
        #expect(ZCodeUserBubbleStyle.verticalPadding == 12)
    }

    @Test("内部间距是 8")
    func innerSpacingIs8() {
        #expect(ZCodeUserBubbleStyle.innerSpacing == 8)
    }

    @Test("正文是 14pt、行高 24")
    func bodyTypographyMatchesZCode() {
        #expect(ZCodeUserBubbleStyle.bodyFontSize == 14)
        #expect(ZCodeUserBubbleStyle.bodyLineHeight == 24)
    }

    @Test("气泡宽度阈值在 624 处切换")
    func bubbleWidthThreshold() {
        // < 624：可用满内容列。
        #expect(ZCodeUserBubbleStyle.bubbleMaxWidth(containerWidth: 623, contentWidth: 623) == 623)
        // ≥ 624：最多 576。
        #expect(ZCodeUserBubbleStyle.bubbleMaxWidth(containerWidth: 624, contentWidth: 624) == 576)
        #expect(ZCodeUserBubbleStyle.bubbleMaxWidth(containerWidth: 1400, contentWidth: 1056) == 576)
    }

    @Test("气泡宽度不会超过内容列宽")
    func bubbleNeverExceedsContentColumn() {
        #expect(ZCodeUserBubbleStyle.bubbleMaxWidth(containerWidth: 400, contentWidth: 400) == 400)
        #expect(ZCodeUserBubbleStyle.bubbleMaxWidth(containerWidth: 700, contentWidth: 604) <= 604)
    }

    // MARK: - 长文折叠

    @Test("长文可见高度是 120")
    func visibleHeightIs120() {
        #expect(ZCodeUserBubbleStyle.collapsedMaxHeight == 120)
    }

    @Test("overflow tolerance 为 1：120/121 不折叠，122 折叠")
    func collapseThresholdHasOnePixelTolerance() {
        #expect(ZCodeUserBubbleStyle.shouldCollapse(contentHeight: 120) == false)
        #expect(ZCodeUserBubbleStyle.shouldCollapse(contentHeight: 121) == false)
        #expect(ZCodeUserBubbleStyle.shouldCollapse(contentHeight: 122) == true)
    }

    @Test("非有限高度不折叠")
    func nonFiniteHeightDoesNotCollapse() {
        #expect(ZCodeUserBubbleStyle.shouldCollapse(contentHeight: .nan) == false)
        #expect(ZCodeUserBubbleStyle.shouldCollapse(contentHeight: .infinity) == false)
    }

    @Test("折叠状态在内容或行身份变化后重置为收起")
    func collapseStateResetsOnIdentityChange() {
        var state = ZCodeUserBubbleCollapseState()

        // 首次观察只记录身份（对应 onAppear），不是「变化」。
        state.updateIdentity(content: "内容", rowID: "row-1")

        state.setExpanded(true)
        #expect(state.isExpanded)

        // 内容变化 → 重新收起。
        state.updateIdentity(content: "新的内容", rowID: "row-1")
        #expect(!state.isExpanded)

        // 行身份变化 → 重新收起。
        state.setExpanded(true)
        state.updateIdentity(content: "新的内容", rowID: "row-2")
        #expect(!state.isExpanded)
    }

    @Test("内容与行身份都不变时保持折叠状态")
    func collapseStateKeepsWhenIdentityUnchanged() {
        var state = ZCodeUserBubbleCollapseState()

        state.updateIdentity(content: "内容", rowID: "row-1")
        state.setExpanded(true)
        state.updateIdentity(content: "内容", rowID: "row-1")

        #expect(state.isExpanded)
    }

    // MARK: - 复制

    @Test("复制使用原始正文而不是裁剪后的内容")
    func copyUsesRawContent() {
        let raw = "  原始正文  \n第二行  "
        #expect(ZCodeUserBubbleStyle.copyText(for: raw) == raw)
    }

    @Test("复制按钮尺寸 24×24、图标 14")
    func copyButtonMetrics() {
        #expect(ZCodeUserBubbleStyle.copyButtonSize == 24)
        #expect(ZCodeUserBubbleStyle.copyButtonIconSize == 14)
    }

    @Test("复制成功反馈在 1200ms 后恢复")
    func copyFeedbackDurationIs1200ms() {
        #expect(ZCodeUserBubbleStyle.copyFeedbackDuration == 1.2)
    }

    @Test("复制状态机在 1200ms 后回到未复制")
    func copyStateResetsAfterFeedbackDuration() {
        var state = ZCodeCopyFeedbackState()

        state.markCopied()
        #expect(state.isCopied)

        // 时间未到 → 仍是已复制。
        state.tick(elapsed: 1.0)
        #expect(state.isCopied)

        // 时间到 → 恢复。
        state.tick(elapsed: 1.2)
        #expect(!state.isCopied)
    }

    @Test("复制状态在再次标记后重新计时")
    func copyStateRestartsOnRepeatedCopy() {
        var state = ZCodeCopyFeedbackState()

        state.markCopied()
        state.tick(elapsed: 1.0)
        state.markCopied()
        state.tick(elapsed: 1.1)
        #expect(state.isCopied)
        state.tick(elapsed: 2.2)
        #expect(!state.isCopied)
    }

    // MARK: - 气泡可见性

    @Test("空正文且无附件时不绘制气泡")
    func noBubbleWithoutContentOrAttachments() {
        #expect(ZCodeUserBubbleStyle.hasVisibleBubble(content: "   ", hasAttachments: false) == false)
    }

    @Test("只有附件时也不绘制气泡")
    func noBubbleForAttachmentOnly() {
        #expect(ZCodeUserBubbleStyle.hasVisibleBubble(content: "", hasAttachments: true) == false)
    }

    @Test("有正文时绘制气泡")
    func bubbleForTextContent() {
        #expect(ZCodeUserBubbleStyle.hasVisibleBubble(content: "你好", hasAttachments: false) == true)
    }

    // MARK: - 附件几何

    @Test("媒体缩略图是 80×80、圆角 12")
    func mediaThumbnailMetrics() {
        #expect(ZCodeUserBubbleStyle.mediaThumbnailSize == 80)
        #expect(ZCodeUserBubbleStyle.mediaThumbnailCornerRadius == 12)
    }

    @Test("非媒体文件 pill 是水平 12、垂直 6、全圆角")
    func filePillMetrics() {
        #expect(ZCodeUserBubbleStyle.filePillHorizontalPadding == 12)
        #expect(ZCodeUserBubbleStyle.filePillVerticalPadding == 6)
        #expect(ZCodeUserBubbleStyle.filePillCornerRadius == .infinity)
        #expect(ZCodeUserBubbleStyle.filePillIconSize == 16)
        #expect(ZCodeUserBubbleStyle.filePillMaxFileNameWidth == 160)
    }

    @Test("附件列最大宽度是 576、底间距 8")
    func attachmentColumnMetrics() {
        #expect(ZCodeUserBubbleStyle.attachmentColumnMaxWidth == 576)
        #expect(ZCodeUserBubbleStyle.attachmentColumnBottomSpacing == 8)
    }

    // MARK: - 动画

    @Test("展开收起动画是 300ms ease-out")
    func collapseAnimationDuration() {
        #expect(ZCodeUserBubbleStyle.collapseAnimationDuration == 0.3)
    }

    @Test("reduceMotion 下没有动画")
    func reducedMotionDisablesAnimation() {
        #expect(ZCodeUserBubbleStyle.animationDuration(reduceMotion: true) == 0)
        #expect(ZCodeUserBubbleStyle.animationDuration(reduceMotion: false) == 0.3)
    }
}
