import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区**内层滚动视图**的滚轮响应能力。
///
/// ## 为什么要锁定这条事实
///
/// 「过程折叠区滚不动」这个问题曾把排查带偏很远：
///
/// - 曾怀疑内层 `NSScrollView` 坏了 → 排除；
/// - 曾怀疑「嵌在 `List` 行里」导致失效 → 排除；
/// - 曾怀疑应用层监视器吞了事件 → 排除；
/// - 曾怀疑跟随状态机把滚动撤销 → 排除。
///
/// 这些排除结论都依赖同一条基础事实：
///
/// > **内层滚动视图本身对滚轮事件有反应。**
///
/// 它一旦被破坏（例如有人给内层加了 `isScrollEnabled = false`、
/// 或把内容换成不可滚的静态视图），「滚不动」的排查就会再次失去锚点。
/// 因此这里把它锁成回归测试。
///
/// ## 重要：合成滚轮事件的坑
///
/// 本文件用**直接调用** `scrollWheel(with:)` 而不是 `window.sendEvent`。
///
/// 原因（实测）：SwiftUI 的 `HostingScrollView` **不接受**投到窗口上的
/// 合成滚轮事件 —— 无论是否带 `phase`、无论投到 `.cghidEventTap` 还是
/// `.cgSessionEventTap`，偏移量恒为 0；而原生 `NSScrollView` 接受同样的
/// 事件（偏移量变化）。
///
/// 也就是说：**用「投事件到窗口」的方式测 SwiftUI `ScrollView` 的滚动，
/// 得到的一定是伪结论。** 直接调用滚动视图自己的 `scrollWheel(with:)`
/// 才是有效路径。
///
/// - Important: 垂直增量必须放在 `wheel1`。`wheel2` 是**水平**轴，
///   误用它会让 `scrollingDeltaY` 恒为 0 —— 那样测出来的
///   「滚不动」全是伪结论。
@MainActor
@Suite("过程折叠区内层滚动视图的滚轮响应")
struct ProcessSectionInnerScrollResponseTests {

    // MARK: - 定位

    /// 祖先链上最近的 `NSScrollView`（即折叠区自己的内层）。
    final class LocatorView: NSView {
        static var inner: NSScrollView?
        /// 祖先链上最远的 `NSScrollView`（即外层 `List`）。
        static var outer: NSScrollView?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            record()
        }

        override func layout() {
            super.layout()
            record()
        }

        private func record() {
            guard window != nil else { return }
            var chain: [NSScrollView] = []
            var current: NSView? = self
            while let candidate = current {
                if let scrollView = candidate as? NSScrollView {
                    chain.append(scrollView)
                }
                current = candidate.superview
            }
            LocatorView.inner = chain.first
            LocatorView.outer = chain.count > 1 ? chain.last : nil
        }
    }

    struct ScrollViewLocator: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            LocatorView(frame: .zero)
        }

        func updateNSView(_ nsView: NSView, context: Context) {}
    }

    // MARK: - 被测内容

    struct SectionContent: View {
        let lineCount: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<lineCount, id: \.self) { index in
                    Text("line-\(index)").frame(height: 20)
                }
                ScrollViewLocator()
                    .frame(height: 1)
            }
        }
    }

    // MARK: - 夹具

    private struct Fixture {
        let window: NSWindow
        let hosting: NSHostingView<AnyView>
        let inner: NSScrollView
        let outer: NSScrollView?
    }

    private func makeFixture<Content: View>(_ content: Content) throws -> Fixture {
        LocatorView.inner = nil
        LocatorView.outer = nil

        let hosting = NSHostingView(rootView: AnyView(content))
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

        let inner = try #require(LocatorView.inner, "未找到内层滚动视图")
        return Fixture(
            window: window,
            hosting: hosting,
            inner: inner,
            outer: LocatorView.outer
        )
    }

    // MARK: - 滚轮事件

    /// 合成一个带**真实垂直滚动增量**的滚轮事件。
    ///
    /// - Important: 垂直增量必须放在 `wheel1`。`wheel2` 是**水平**轴，
    ///   误用它会让 `scrollingDeltaY` 恒为 0 —— 那样测出来的
    ///   「滚不动」全是伪结论。
    private func makeScrollWheelEvent(deltaY: CGFloat) -> NSEvent? {
        guard let cgEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: 0,
            wheel3: 0
        ) else {
            return nil
        }
        return NSEvent(cgEvent: cgEvent)
    }

    private func maxOffset(of scrollView: NSScrollView) -> CGFloat {
        max(0, (scrollView.documentView?.bounds.height ?? 0) - scrollView.contentView.bounds.height)
    }

    /// 把内层滚到中间，保证「有可滚空间」。
    private func parkAtMiddle(_ scrollView: NSScrollView) {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxOffset(of: scrollView) / 2))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    // MARK: - 用例

    @Test("内层滚动视图对滚轮事件有反应")
    func innerRespondsToScrollWheel() throws {
        let fixture = try makeFixture(
            List {
                BoundedProcessSection(maxHeight: 200, contentVersion: 40) {
                    SectionContent(lineCount: 40)
                }
            }
            .listStyle(.plain)
        )
        defer {
            // 渲染 `BoundedProcessSection` 会让它向全局单例
            // `ProcessSectionScrollRelay.shared` 登记内层滚动视图。
            // 不注销的话，单例状态会漏到后续用例里
            // （`ProcessSectionScrollRelayTests` 断言「最后一个观察者注销后
            // 移除监视器」，会被这条残留登记打破）。
            ProcessSectionScrollRelay.shared.unregister(fixture.inner)
            fixture.window.orderOut(nil)
            fixture.hosting.removeFromSuperview()
        }

        let inner = fixture.inner
        #expect(
            maxOffset(of: inner) > 0,
            "内容应超出视口，否则没有可滚空间"
        )

        parkAtMiddle(inner)
        let before = inner.contentView.bounds.origin.y

        guard let event = makeScrollWheelEvent(deltaY: 40) else {
            Issue.record("无法合成滚轮事件")
            return
        }
        #expect(
            event.scrollingDeltaY != 0,
            "合成事件的垂直增量必须非零，否则结论无效"
        )

        inner.scrollWheel(with: event)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let after = inner.contentView.bounds.origin.y

        #expect(
            after != before,
            """
            内层滚动视图必须对滚轮事件有反应。\
            before=\(before) after=\(after)\
            —— 内层失去滚轮响应时，「滚不动」的排查就失去了锚点。
            """
        )
    }

    @Test("内层确实嵌在外层 List 里（嵌套结构成立）")
    func innerIsNestedInsideOuterList() throws {
        let fixture = try makeFixture(
            List {
                BoundedProcessSection(maxHeight: 200, contentVersion: 40) {
                    SectionContent(lineCount: 40)
                }
            }
            .listStyle(.plain)
        )
        defer {
            ProcessSectionScrollRelay.shared.unregister(fixture.inner)
            fixture.window.orderOut(nil)
            fixture.hosting.removeFromSuperview()
        }

        #expect(
            fixture.outer != nil,
            "折叠区应嵌在 `List` 的滚动视图里"
        )
        #expect(
            fixture.outer !== fixture.inner,
            "内层与外层应是两个不同的滚动视图"
        )
    }
}
