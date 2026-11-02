import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区的**自动钉底**渲染级测试。
///
/// ## 为什么必须做渲染级验证
///
/// 「内容增长时自动钉底、用户上滚后可打断」是这个功能的**全部价值**。
/// 而它依赖的是 AppKit 层两个通知的互斥性 —— 这是纯函数测试无法覆盖的：
/// 单测只能测「给定输入应得出什么结论」，测不出「SwiftUI 的
/// `ScrollView` 在内容变高时到底会不会发那个通知」，也测不出
/// 「钉底动作在真实滚动视图上是否真的生效」。
///
/// 因此这里直接渲染**生产组件** `BoundedProcessSection`，用真实的
/// AppKit 滚动视图驱动，断言真实的偏移量。
@MainActor
@Suite("过程折叠区自动钉底的渲染级测试")
struct ProcessSectionAutoPinRenderTests {
    /// 驱动探针内容的可观测模型。
    final class Model: ObservableObject {
        @Published var lineCount: Int
        init(lineCount: Int) {
            self.lineCount = lineCount
        }
    }

    /// 定位生产组件内部滚动视图的探针。
    ///
    /// - Important: 探针放在 `BoundedProcessSection` 的 `content` 里 ——
    ///   它是内容的一部分，因此它的 `enclosingScrollView` 正是生产组件
    ///   的内层滚动视图（不是外层 List 的）。
    final class LocatorView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            ScrollViewLocator.inner = enclosingScrollView
        }

        override func layout() {
            super.layout()
            if ScrollViewLocator.inner == nil {
                ScrollViewLocator.inner = enclosingScrollView
            }
        }
    }

    /// 探针的 SwiftUI 包装。
    struct ScrollViewLocator: NSViewRepresentable {
        static var inner: NSScrollView?

        func makeNSView(context: Context) -> NSView {
            LocatorView(frame: .zero)
        }

        func updateNSView(_ nsView: NSView, context: Context) {}
    }

    /// 被测视图：直接使用生产组件 `BoundedProcessSection`。
    struct Subject: View {
        @ObservedObject var model: Model

        var body: some View {
            BoundedProcessSection(maxHeight: 200, contentVersion: model.lineCount) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<model.lineCount, id: \.self) { index in
                        Text("line-\(index)").frame(height: 20)
                    }
                    ScrollViewLocator()
                        .frame(height: 1)
                }
            }
        }
    }

    /// 搭建窗口并返回生产组件的内层滚动视图。
    private func makeInnerScrollView(model: Model) throws -> NSScrollView {
        ScrollViewLocator.inner = nil
        let hosting = NSHostingView(rootView: Subject(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 600)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(hosting)
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        return try #require(ScrollViewLocator.inner, "未取得内层滚动视图")
    }

    /// 当前偏移量与最大偏移量。
    private func offsetState(_ scrollView: NSScrollView) -> (offset: CGFloat, maxOffset: CGFloat) {
        print("🧪 TEST sees scroll=\(String(describing: type(of: scrollView))) offset=\(scrollView.contentView.bounds.origin.y) docH=\(scrollView.documentView?.bounds.height ?? -1) clipH=\(scrollView.contentView.bounds.height)")
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        let visibleHeight = scrollView.contentView.bounds.height
        let maxOffset = max(0, documentHeight - visibleHeight)
        return (scrollView.contentView.bounds.origin.y, maxOffset)
    }

    // MARK: - 用例

    @Test("展开后初始即定位到底部，最新内容在底部可见")
    func initialPositionIsAtBottom() throws {
        let model = Model(lineCount: 40)
        let inner = try makeInnerScrollView(model: model)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        let state = offsetState(inner)
        #expect(
            abs(state.offset - state.maxOffset) <= 1,
            """
            展开一个内容超长的折叠区后，视口应已定位到底部（最新内容可见）。\
            offset=\(state.offset) maxOffset=\(state.maxOffset)
            """
        )
    }

    @Test("内容增长时自动钉到底部，新内容始终在底部出现")
    func contentGrowthPinsToBottom() throws {
        let model = Model(lineCount: 5)
        let inner = try makeInnerScrollView(model: model)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        // 内容持续增长（模拟 LLM 动作一个个落库）。
        for count in [15, 25, 35] {
            model.lineCount = count
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            let state = offsetState(inner)
            #expect(
                abs(state.offset - state.maxOffset) <= 1,
                """
                内容增长到 \(count) 行后应钉在底部。\
                offset=\(state.offset) maxOffset=\(state.maxOffset)
                """
            )
        }
    }

    @Test("用户上滚打断后，内容增长不再把视口拽回底部")
    func userScrollBreaksAutoPin() throws {
        let model = Model(lineCount: 40)
        let inner = try makeInnerScrollView(model: model)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        // 用户主动上滚：离开底部。
        inner.contentView.scroll(to: NSPoint(x: 0, y: 100))
        inner.reflectScrolledClipView(inner.contentView)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))

        let beforeGrow = offsetState(inner)
        #expect(
            beforeGrow.offset < beforeGrow.maxOffset,
            "上滚后应离开底部（前置条件）"
        )

        // 内容继续增长 —— 不应被拽回底部。
        model.lineCount = 60
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let afterGrow = offsetState(inner)

        #expect(
            afterGrow.offset < afterGrow.maxOffset,
            """
            用户已上滚，内容增长不得把视口拽回底部。\
            offset=\(afterGrow.offset) maxOffset=\(afterGrow.maxOffset)
            """
        )
    }

    @Test("用户滚回底部后，跟随恢复")
    func resumesFollowingWhenBackAtBottom() throws {
        let model = Model(lineCount: 40)
        let inner = try makeInnerScrollView(model: model)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        // 上滚打断。
        inner.contentView.scroll(to: NSPoint(x: 0, y: 100))
        inner.reflectScrolledClipView(inner.contentView)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))

        // 用户滚回底部。
        let state = offsetState(inner)
        inner.contentView.scroll(to: NSPoint(x: 0, y: state.maxOffset))
        inner.reflectScrolledClipView(inner.contentView)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))

        // 内容增长 —— 应重新钉到底部。
        model.lineCount = 60
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let afterGrow = offsetState(inner)

        #expect(
            abs(afterGrow.offset - afterGrow.maxOffset) <= 1,
            """
            用户滚回底部后，跟随应恢复。\
            offset=\(afterGrow.offset) maxOffset=\(afterGrow.maxOffset)
            """
        )
    }
}
