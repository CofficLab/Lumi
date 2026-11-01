import CoreGraphics
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区的高度上限规则。
///
/// 这些参数直接决定展开区的观感（多高开始滚动），必须锁死：
/// 比例一改，全局手感就变了。
struct ProcessSectionLayoutTests {
    // MARK: - 上限

    @Test("上限取视口的 60%")
    func maxHeightUsesViewportFraction() {
        #expect(ProcessSectionLayout.maxHeight(viewportHeight: 1000) == 600)
        #expect(ProcessSectionLayout.maxHeight(viewportHeight: 800) == 480)
    }

    @Test("视口过矮时上限落到绝对下限，不会小到看不见")
    func maxHeightFallsBackToMinimum() {
        // 视口 100pt → 60% 只有 60pt，比下限还小。
        #expect(ProcessSectionLayout.maxHeight(viewportHeight: 100) == ProcessSectionLayout.minimumMaxHeight)
        // 恰好等于下限。
        #expect(
            ProcessSectionLayout.maxHeight(viewportHeight: ProcessSectionLayout.minimumMaxHeight / ProcessSectionLayout.maxHeightFraction)
                == ProcessSectionLayout.minimumMaxHeight
        )
    }

    @Test("视口未就绪时退回下限，折叠区不会消失")
    func maxHeightHandlesInvalidViewport() {
        #expect(ProcessSectionLayout.maxHeight(viewportHeight: 0) == ProcessSectionLayout.minimumMaxHeight)
        #expect(ProcessSectionLayout.maxHeight(viewportHeight: -100) == ProcessSectionLayout.minimumMaxHeight)
        #expect(ProcessSectionLayout.maxHeight(viewportHeight: .nan) == ProcessSectionLayout.minimumMaxHeight)
        #expect(ProcessSectionLayout.maxHeight(viewportHeight: .infinity) == ProcessSectionLayout.minimumMaxHeight)
    }

    // MARK: - 实际占用高度

    @Test("内容短于上限时高度自适应，不补空白")
    func shortContentUsesContentHeight() {
        #expect(ProcessSectionLayout.resolvedHeight(contentHeight: 120, maxHeight: 480) == 120)
    }

    @Test("内容超过上限时封顶")
    func longContentIsCapped() {
        #expect(ProcessSectionLayout.resolvedHeight(contentHeight: 2000, maxHeight: 480) == 480)
    }

    @Test("内容恰好等于上限时按上限取值")
    func exactContentUsesMaxHeight() {
        #expect(ProcessSectionLayout.resolvedHeight(contentHeight: 480, maxHeight: 480) == 480)
    }

    @Test("尚未测量时先按上限占位，内容不会凭空消失")
    func unmeasuredContentUsesMaxHeight() {
        #expect(ProcessSectionLayout.resolvedHeight(contentHeight: nil, maxHeight: 480) == 480)
        #expect(ProcessSectionLayout.resolvedHeight(contentHeight: 0, maxHeight: 480) == 480)
        #expect(ProcessSectionLayout.resolvedHeight(contentHeight: .nan, maxHeight: 480) == 480)
    }

    // MARK: - 溢出判定

    @Test("内容超出上限才判定为溢出")
    func overflowDetection() {
        #expect(ProcessSectionLayout.isOverflowing(contentHeight: 481, maxHeight: 480))
        #expect(!ProcessSectionLayout.isOverflowing(contentHeight: 480, maxHeight: 480))
        #expect(!ProcessSectionLayout.isOverflowing(contentHeight: 100, maxHeight: 480))
    }

    @Test("非法高度不判定为溢出")
    func overflowIgnoresInvalidHeights() {
        #expect(!ProcessSectionLayout.isOverflowing(contentHeight: .nan, maxHeight: 480))
        #expect(!ProcessSectionLayout.isOverflowing(contentHeight: 1000, maxHeight: .nan))
    }
}
