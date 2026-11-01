import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区的滚动接力。
///
/// 接力要解决的是：macOS 的嵌套滚动视图**默认没有滚动链** ——
/// 内层到底后继续拖动，外层列表纹丝不动，手感上像是「卡住了」。
@MainActor
struct ProcessSectionScrollRelayTests {
    // MARK: - 边界判定

    @Test("内层已到底时向下滚，增量让给外层")
    func forwardsWhenInnerReachesBottom() {
        // 文档 1000、可视 300 → maxOffset = 700
        #expect(ProcessSectionScrollRelay.shouldForward(
            deltaY: 50,
            currentOffsetY: 700,
            documentHeight: 1_000,
            visibleHeight: 300
        ))
    }

    @Test("内层未到底时向下滚，增量留在内层")
    func keepsScrollInsideInnerWhenNotAtBoundary() {
        #expect(!ProcessSectionScrollRelay.shouldForward(
            deltaY: 50,
            currentOffsetY: 300,
            documentHeight: 1_000,
            visibleHeight: 300
        ))
    }

    @Test("内层已到顶时向上滚，增量让给外层")
    func forwardsWhenInnerReachesTop() {
        #expect(ProcessSectionScrollRelay.shouldForward(
            deltaY: -50,
            currentOffsetY: 0,
            documentHeight: 1_000,
            visibleHeight: 300
        ))
    }

    @Test("内层不在顶部时向上滚，增量留在内层")
    func keepsScrollInsideInnerWhenNotAtTop() {
        #expect(!ProcessSectionScrollRelay.shouldForward(
            deltaY: -50,
            currentOffsetY: 300,
            documentHeight: 1_000,
            visibleHeight: 300
        ))
    }

    @Test("边界判定留 1pt 容差，不会出现「差一点点就卡住」")
    func boundaryUsesOnePointTolerance() {
        // 距离底部还差 0.5pt：算到底
        #expect(ProcessSectionScrollRelay.shouldForward(
            deltaY: 10,
            currentOffsetY: 699.5,
            documentHeight: 1_000,
            visibleHeight: 300
        ))
        // 距离底部还差 2pt：不算到底
        #expect(!ProcessSectionScrollRelay.shouldForward(
            deltaY: 10,
            currentOffsetY: 698,
            documentHeight: 1_000,
            visibleHeight: 300
        ))
    }

    @Test("内容不足以滚动时不接力")
    func doesNotForwardWhenContentFits() {
        // 文档 200、可视 300 → maxOffset = 0，始终在底部
        #expect(ProcessSectionScrollRelay.shouldForward(
            deltaY: 50,
            currentOffsetY: 0,
            documentHeight: 200,
            visibleHeight: 300
        ))
    }

    @Test("零增量与非法几何不接力")
    func rejectsInvalidInput() {
        #expect(!ProcessSectionScrollRelay.shouldForward(
            deltaY: 0,
            currentOffsetY: 700,
            documentHeight: 1_000,
            visibleHeight: 300
        ))
        #expect(!ProcessSectionScrollRelay.shouldForward(
            deltaY: 50,
            currentOffsetY: 700,
            documentHeight: .nan,
            visibleHeight: 300
        ))
        #expect(!ProcessSectionScrollRelay.shouldForward(
            deltaY: 50,
            currentOffsetY: 700,
            documentHeight: 1_000,
            visibleHeight: 0
        ))
    }

    // MARK: - 登记

    @Test("登记与注销是幂等的")
    func registrationIsIdempotent() {
        let relay = ProcessSectionScrollRelay.shared
        let scrollView = NSScrollView()
        defer { relay.unregister(scrollView) }

        #expect(!relay.isRegistered(scrollView))
        relay.register(scrollView)
        relay.register(scrollView)
        #expect(relay.isRegistered(scrollView))

        relay.unregister(scrollView)
        relay.unregister(scrollView)
        #expect(!relay.isRegistered(scrollView))
    }
}
